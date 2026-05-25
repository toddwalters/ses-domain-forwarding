"use strict";

const CONFIG_PARAMETER_NAME = process.env.CONFIG_PARAMETER_NAME;
const INBOUND_BUCKET_NAME = process.env.INBOUND_BUCKET_NAME;

let cachedConfig;

function log(data, entry) {
  const logger = data.log || console.log;
  const payload = {
    timestamp: new Date().toISOString(),
    awsRequestId: data.context && data.context.awsRequestId,
    sesMessageId: data.email && data.email.messageId,
    domain: data.domain,
    ...entry
  };
  logger(JSON.stringify(payload));
}

function normalizeEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function domainFromEmail(email) {
  const normalized = normalizeEmail(email);
  const at = normalized.lastIndexOf("@");
  return at === -1 ? "" : normalized.slice(at + 1);
}

function localPartFromEmail(email) {
  const normalized = normalizeEmail(email);
  const at = normalized.lastIndexOf("@");
  return at === -1 ? normalized : normalized.slice(0, at);
}

function unique(values) {
  return [...new Set(values)];
}

function resolveForwardingMatch(domainConfig, originalRecipient) {
  const mapping = domainConfig.forwardMapping || {};
  const normalized = normalizeEmail(originalRecipient);
  const domain = domainFromEmail(normalized);
  const localPart = localPartFromEmail(normalized);
  const candidates = [
    { key: normalized, matchType: "exact" },
    { key: domain ? `@${domain}` : "", matchType: "catch_all" },
    { key: localPart, matchType: "local_part" }
  ].filter((candidate) => candidate.key);

  for (const candidate of candidates) {
    if (mapping[candidate.key]) {
      return {
        originalRecipient: normalized,
        matchedRule: candidate.key,
        matchType: candidate.matchType,
        destinations: mapping[candidate.key]
      };
    }
  }

  return null;
}

function makeCommand(data, name, input) {
  const Command = data.commands && data.commands[name];
  if (!Command) {
    throw new Error(`Missing command constructor: ${name}`);
  }
  return new Command(input);
}

async function streamToString(stream) {
  if (!stream) {
    return "";
  }
  if (typeof stream.transformToString === "function") {
    return stream.transformToString();
  }

  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf8");
}

async function loadAwsRuntime() {
  const s3 = await import("@aws-sdk/client-s3");
  const ses = await import("@aws-sdk/client-ses");
  const ssm = await import("@aws-sdk/client-ssm");

  return {
    clients: {
      s3: new s3.S3Client(),
      ses: new ses.SESClient(),
      ssm: new ssm.SSMClient()
    },
    commands: {
      GetObjectCommand: s3.GetObjectCommand,
      SendRawEmailCommand: ses.SendRawEmailCommand,
      GetParameterCommand: ssm.GetParameterCommand
    }
  };
}

async function loadConfig(data) {
  if (data.config) {
    return data;
  }
  if (cachedConfig) {
    data.config = cachedConfig;
    return data;
  }
  if (!CONFIG_PARAMETER_NAME) {
    throw new Error("CONFIG_PARAMETER_NAME is required.");
  }

  const result = await data.ssm.send(makeCommand(data, "GetParameterCommand", {
    Name: CONFIG_PARAMETER_NAME
  }));

  cachedConfig = JSON.parse(result.Parameter.Value);
  data.config = cachedConfig;
  return data;
}

async function parseEvent(data) {
  const records = data.event && data.event.Records;
  const record = records && records[0];

  if (!records || records.length !== 1 || record.eventSource !== "aws:ses" || record.eventVersion !== "1.0") {
    log(data, { level: "error", message: "Invalid SES event." });
    throw new Error("Received invalid SES message.");
  }

  data.email = record.ses.mail;
  data.originalRecipients = record.ses.receipt.recipients || [];
  log(data, {
    level: "info",
    message: "Parsed SES event.",
    originalRecipients: data.originalRecipients
  });
  return data;
}

function resolveDomainConfig(config, recipients) {
  const domains = (config && config.domains) || {};
  for (const recipient of recipients) {
    const domain = domainFromEmail(recipient);
    if (domains[domain]) {
      return { domain, config: domains[domain] };
    }
  }
  return null;
}

async function selectDomainConfig(data) {
  const selected = resolveDomainConfig(data.config, data.originalRecipients);
  if (!selected) {
    data.stop = true;
    data.stopReason = "No configured domain matched the original recipients.";
    log(data, {
      level: "info",
      message: data.stopReason,
      recipients: data.originalRecipients
    });
    return data;
  }

  data.domain = selected.domain;
  data.domainConfig = selected.config;
  data.domainConfig.emailBucket = data.domainConfig.emailBucket || INBOUND_BUCKET_NAME;
  if (!data.domainConfig.emailBucket) {
    throw new Error(`No inbound bucket configured for ${data.domain}.`);
  }
  log(data, {
    level: "info",
    message: "Selected domain configuration.",
    originalRecipients: data.originalRecipients
  });
  return data;
}

function recipientsForAddress(domainConfig, originalRecipient) {
  const match = resolveForwardingMatch(domainConfig, originalRecipient);
  return match ? match.destinations : [];
}

async function transformRecipients(data) {
  if (data.stop) {
    return data;
  }

  const transformed = [];
  data.recipientMatches = [];
  for (const recipient of data.originalRecipients) {
    const match = resolveForwardingMatch(data.domainConfig, recipient);
    const resolved = match ? match.destinations : [];
    if (resolved.length > 0 && !data.originalRecipient) {
      data.originalRecipient = recipient;
    }
    if (match) {
      data.recipientMatches.push(match);
    }
    transformed.push(...resolved);
  }

  data.recipients = unique(transformed);
  if (data.recipients.length === 0) {
    data.stop = true;
    data.stopReason = "No forwarding recipients matched the original recipients.";
    log(data, {
      level: "info",
      message: data.stopReason,
      recipients: data.originalRecipients
    });
  } else {
    log(data, {
      level: "info",
      message: "Resolved forwarding recipients.",
      originalRecipient: data.originalRecipient,
      recipientMatches: data.recipientMatches,
      transformedRecipients: data.recipients
    });
  }
  return data;
}

async function fetchMessage(data) {
  if (data.stop) {
    return data;
  }

  const prefix = data.domainConfig.emailKeyPrefix || "";
  data.emailKey = `${prefix}${data.email.messageId}`;

  log(data, {
    level: "info",
    message: "Fetching raw email from S3.",
    bucket: data.domainConfig.emailBucket,
    key: data.emailKey,
    domain: data.domain
  });

  const result = await data.s3.send(makeCommand(data, "GetObjectCommand", {
    Bucket: data.domainConfig.emailBucket,
    Key: data.emailKey
  }));

  data.emailData = await streamToString(result.Body);
  return data;
}

async function processMessage(data) {
  if (data.stop) {
    return data;
  }

  const match = data.emailData.match(/^((?:.+\r?\n)*)(\r?\n(?:.*\s+)*)/m);
  let header = match && match[1] ? match[1] : data.emailData;
  const body = match && match[2] ? match[2] : "";

  if (!/^Reply-To: /mi.test(header)) {
    const fromMatch = header.match(/^From: (.*(?:\r?\n\s+.*)*\r?\n)/m);
    const from = fromMatch && fromMatch[1] ? fromMatch[1] : "";
    if (from) {
      header = `${header}Reply-To: ${from}`;
    }
  }

  header = header.replace(/^From: (.*(?:\r?\n\s+.*)*)/mg, (matched, from) => {
    if (data.domainConfig.fromEmail) {
      return `From: ${from.replace(/<(.*)>/, "").trim()} <${data.domainConfig.fromEmail}>`;
    }
    return `From: ${from.replace("<", "at ").replace(">", "")} <${data.originalRecipient}>`;
  });

  if (data.domainConfig.subjectPrefix) {
    header = header.replace(/^Subject: (.*)/mg, (matched, subject) => {
      return `Subject: ${data.domainConfig.subjectPrefix}${subject}`;
    });
  }

  header = header.replace(/^Return-Path: (.*)\r?\n/mg, "");
  header = header.replace(/^Sender: (.*)\r?\n/mg, "");
  header = header.replace(/^Message-ID: (.*)\r?\n/mig, "");
  header = header.replace(/^DKIM-Signature: .*\r?\n(\s+.*\r?\n)*/mg, "");

  data.emailData = header + body;
  return data;
}

async function sendMessage(data) {
  if (data.stop) {
    return data;
  }

  const params = {
    Destinations: data.recipients,
    Source: data.originalRecipient,
    RawMessage: {
      Data: data.emailData
    }
  };

  log(data, {
    level: "info",
    message: "Sending forwarded email via SES.",
    originalRecipient: data.originalRecipient,
    originalRecipients: data.originalRecipients,
    recipientMatches: data.recipientMatches,
    transformedRecipients: data.recipients
  });

  data.sendResult = await data.ses.send(makeCommand(data, "SendRawEmailCommand", params));
  return data;
}

async function handler(event, context, overrides = {}) {
  const runtime = overrides.clients && overrides.commands ? overrides : await loadAwsRuntime();
  const steps = overrides.steps || [
    loadConfig,
    parseEvent,
    selectDomainConfig,
    transformRecipients,
    fetchMessage,
    processMessage,
    sendMessage
  ];

  let data = {
    event,
    context,
    config: overrides.config,
    log: overrides.log || console.log,
    s3: runtime.clients.s3,
    ses: runtime.clients.ses,
    ssm: runtime.clients.ssm,
    commands: runtime.commands
  };

  try {
    for (const step of steps) {
      data = await step(data);
    }
    if (data.stop) {
      log(data, {
        level: "info",
        message: "Forwarding stopped.",
        outcome: "skipped",
        reason: data.stopReason
      });
      return { status: "skipped", reason: data.stopReason };
    }
    log(data, {
      level: "info",
      message: "Forwarding finished successfully.",
      outcome: "sent",
      originalRecipient: data.originalRecipient,
      transformedRecipients: data.recipients,
      forwardedMessageId: data.sendResult && data.sendResult.MessageId
    });
    return { status: "sent", messageId: data.sendResult && data.sendResult.MessageId };
  } catch (err) {
    log(data, {
      level: "error",
      message: "Forwarding failed.",
      outcome: "failed",
      errorMessage: err.message,
      stack: err.stack,
      originalRecipients: data.originalRecipients,
      originalRecipient: data.originalRecipient,
      transformedRecipients: data.recipients
    });
    throw err;
  }
}

module.exports = {
  domainFromEmail,
  fetchMessage,
  handler,
  loadConfig,
  localPartFromEmail,
  log,
  normalizeEmail,
  parseEvent,
  processMessage,
  recipientsForAddress,
  resolveDomainConfig,
  resolveForwardingMatch,
  selectDomainConfig,
  sendMessage,
  transformRecipients
};
