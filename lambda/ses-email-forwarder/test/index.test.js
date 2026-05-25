"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const forwarder = require("../index");

const config = {
  domains: {
    "example.com": {
      fromEmail: "noreply@example.com",
      subjectPrefix: "",
      emailBucket: "test-bucket",
      emailKeyPrefix: "domains/example.com/",
      forwardMapping: {
        "info@example.com": ["forward-target@example.net"],
        "abuse@example.com": ["abuse-target@example.net"],
        "@example.com": ["catchall@example.net"],
        "info": ["local-info@example.com"]
      }
    }
  }
};

function sesEvent(recipients = ["info@example.com"], messageId = "message-1") {
  return {
    Records: [
      {
        eventSource: "aws:ses",
        eventVersion: "1.0",
        ses: {
          mail: {
            messageId
          },
          receipt: {
            recipients
          }
        }
      }
    ]
  };
}

function data(overrides = {}) {
  return {
    event: sesEvent(),
    config,
    log: () => {},
    ...overrides
  };
}

test("parses a valid SES event", async () => {
  const result = await forwarder.parseEvent(data({ event: sesEvent(["abuse@example.com"], "abc123") }));

  assert.equal(result.email.messageId, "abc123");
  assert.deepEqual(result.originalRecipients, ["abuse@example.com"]);
});

test("rejects an invalid SES event", async () => {
  await assert.rejects(
    () => forwarder.parseEvent(data({ event: { Records: [] } })),
    /Received invalid SES message/
  );
});

test("resolves exact address mappings before catch-all mappings", async () => {
  let result = await forwarder.parseEvent(data({ event: sesEvent(["info@example.com"]) }));
  result = await forwarder.selectDomainConfig(result);
  result = await forwarder.transformRecipients(result);

  assert.deepEqual(result.recipients, ["forward-target@example.net"]);
  assert.equal(result.originalRecipient, "info@example.com");
});

test("resolves domain catch-all mappings", async () => {
  let result = await forwarder.parseEvent(data({ event: sesEvent(["hello@example.com"]) }));
  result = await forwarder.selectDomainConfig(result);
  result = await forwarder.transformRecipients(result);

  assert.deepEqual(result.recipients, ["catchall@example.net"]);
  assert.equal(result.originalRecipient, "hello@example.com");
});

test("resolves mailbox-name mappings when no exact or domain mapping exists", async () => {
  const localConfig = {
    domains: {
      "example.com": {
        emailBucket: "test-bucket",
        emailKeyPrefix: "domains/example.com/",
        forwardMapping: {
          info: ["local-info@example.com"]
        }
      }
    }
  };

  let result = await forwarder.parseEvent(data({
    config: localConfig,
    event: sesEvent(["info@example.com"])
  }));
  result = await forwarder.selectDomainConfig(result);
  result = await forwarder.transformRecipients(result);

  assert.deepEqual(result.recipients, ["local-info@example.com"]);
});

test("stops when no configured domain matches", async () => {
  let result = await forwarder.parseEvent(data({ event: sesEvent(["info@elsewhere.test"]) }));
  result = await forwarder.selectDomainConfig(result);

  assert.equal(result.stop, true);
  assert.match(result.stopReason, /No configured domain/);
});

test("returns structured forwarding match details", () => {
  const match = forwarder.resolveForwardingMatch(config.domains["example.com"], "hello@example.com");

  assert.deepEqual(match, {
    originalRecipient: "hello@example.com",
    matchedRule: "@example.com",
    matchType: "catch_all",
    destinations: ["catchall@example.net"]
  });
});

test("fetches from the configured S3 prefix", async () => {
  class GetObjectCommand {
    constructor(input) {
      this.input = input;
    }
  }

  const sent = [];
  const result = await forwarder.fetchMessage(data({
    email: { messageId: "message-123" },
    domain: "example.com",
    domainConfig: config.domains["example.com"],
    s3: {
      send: async (command) => {
        sent.push(command.input);
        return { Body: { transformToString: async () => "From: A <a@example.com>\n\nBody" } };
      }
    },
    commands: { GetObjectCommand }
  }));

  assert.equal(result.emailKey, "domains/example.com/message-123");
  assert.deepEqual(sent[0], {
    Bucket: "test-bucket",
    Key: "domains/example.com/message-123"
  });
  assert.match(result.emailData, /Body/);
});

test("rewrites headers without logging or parsing full MIME content", async () => {
  const result = await forwarder.processMessage(data({
    originalRecipient: "info@example.com",
    domainConfig: config.domains["example.com"],
    emailData: [
      "Return-Path: <sender@example.com>",
      "From: Sender <sender@example.com>",
      "Sender: sender@example.com",
      "Message-ID: <abc>",
      "DKIM-Signature: old",
      "Subject: Hello",
      "",
      "Body"
    ].join("\n")
  }));

  assert.match(result.emailData, /^From: Sender <noreply@example.com>/m);
  assert.match(result.emailData, /^Reply-To: Sender <sender@example.com>/m);
  assert.doesNotMatch(result.emailData, /^Return-Path:/m);
  assert.doesNotMatch(result.emailData, /^Sender:/m);
  assert.doesNotMatch(result.emailData, /^Message-ID:/mi);
  assert.doesNotMatch(result.emailData, /^DKIM-Signature:/m);
});

test("handler can run end-to-end with injected clients", async () => {
  class GetObjectCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class SendRawEmailCommand {
    constructor(input) {
      this.input = input;
    }
  }
  const sentCommands = [];
  const logs = [];

  const result = await forwarder.handler(sesEvent(["hello@example.com"], "message-abc"), {}, {
    config,
    log: (entry) => logs.push(JSON.parse(entry)),
    clients: {
      s3: {
        send: async () => ({
          Body: { transformToString: async () => "From: Sender <sender@example.com>\nSubject: Hi\n\nBody" }
        })
      },
      ses: {
        send: async (command) => {
          sentCommands.push(command.input);
          return { MessageId: "sent-1" };
        }
      },
      ssm: {
        send: async () => {
          throw new Error("SSM should not be called when config is injected");
        }
      }
    },
    commands: {
      GetObjectCommand,
      SendRawEmailCommand
    }
  });

  assert.deepEqual(result, { status: "sent", messageId: "sent-1" });
  assert.deepEqual(sentCommands[0].Destinations, ["catchall@example.net"]);
  assert.equal(sentCommands[0].Source, "hello@example.com");

  const routingLog = logs.find((entry) => entry.message === "Resolved forwarding recipients.");
  assert.deepEqual(routingLog.recipientMatches, [
    {
      originalRecipient: "hello@example.com",
      matchedRule: "@example.com",
      matchType: "catch_all",
      destinations: ["catchall@example.net"]
    }
  ]);

  const successLog = logs.find((entry) => entry.message === "Forwarding finished successfully.");
  assert.equal(successLog.outcome, "sent");
  assert.equal(successLog.sesMessageId, "message-abc");
  assert.equal(successLog.forwardedMessageId, "sent-1");
});

test("handler logs structured failures", async () => {
  const logs = [];

  await assert.rejects(
    () => forwarder.handler(sesEvent(["info@example.com"], "message-fail"), { awsRequestId: "req-1" }, {
      config,
      log: (entry) => logs.push(JSON.parse(entry)),
      steps: [
        async (input) => forwarder.loadConfig(input),
        async (input) => forwarder.parseEvent(input),
        async () => {
          throw new Error("boom");
        }
      ],
      clients: {
        s3: {},
        ses: {},
        ssm: {}
      },
      commands: {}
    }),
    /boom/
  );

  const failureLog = logs.find((entry) => entry.message === "Forwarding failed.");
  assert.equal(failureLog.outcome, "failed");
  assert.equal(failureLog.awsRequestId, "req-1");
  assert.equal(failureLog.sesMessageId, "message-fail");
  assert.equal(failureLog.errorMessage, "boom");
});
