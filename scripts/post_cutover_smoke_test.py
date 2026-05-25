#!/usr/bin/env python3

import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone


def run_aws_json(args):
    result = subprocess.run(
        ["aws", *args, "--output", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def run_aws_text(args):
    result = subprocess.run(
        ["aws", *args, "--output", "text"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def normalize_bool(value):
    return str(value).strip().lower() == "true"


def normalize_nameservers(values):
    return sorted(value.rstrip(".").lower() for value in values)


def rule_name_for_domain(domain):
    return f"{domain.replace('.', '-')}-forwarding"


def get_metric_sum(region, function_name, metric_name, hours):
    end_time = datetime.now(timezone.utc)
    start_time = end_time - timedelta(hours=hours)
    payload = run_aws_json(
        [
            "cloudwatch",
            "get-metric-statistics",
            "--region",
            region,
            "--namespace",
            "AWS/Lambda",
            "--metric-name",
            metric_name,
            "--dimensions",
            f"Name=FunctionName,Value={function_name}",
            "--start-time",
            start_time.isoformat(),
            "--end-time",
            end_time.isoformat(),
            "--period",
            "3600",
            "--statistics",
            "Sum",
        ]
    )
    datapoints = payload.get("Datapoints", [])
    total = sum(point.get("Sum", 0) for point in datapoints)
    return int(total) if total == int(total) else round(total, 2)


def append_summary(lines):
    summary_path = os.getenv("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return
    with open(summary_path, "a", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
        handle.write("\n")


def main():
    domain_hosted_zones_path = os.environ["DOMAIN_HOSTED_ZONES_JSON"]
    expected_rule_set_name = os.environ["EXPECTED_RULE_SET_NAME"]
    region = os.environ["AWS_REGION_VAR"]
    bucket_name = os.environ["SHARED_BUCKET_NAME"]
    lambda_arn = os.environ["FORWARDER_LAMBDA_ARN"]
    requested_domain = os.getenv("SMOKE_TEST_DOMAIN", "").strip().lower()

    with open(domain_hosted_zones_path, encoding="utf-8") as handle:
        domain_hosted_zones = json.load(handle)

    selected_domains = sorted(domain_hosted_zones.keys())
    if requested_domain:
        if requested_domain not in domain_hosted_zones:
            print(
                f"Requested domain '{requested_domain}' is not present in Terraform outputs.",
                file=sys.stderr,
            )
            return 2
        selected_domains = [requested_domain]

    lambda_name = lambda_arn.split(":")[-1]

    account_status = run_aws_json(["sesv2", "get-account", "--region", region])
    production_enabled = normalize_bool(
        account_status.get("ProductionAccessEnabled", False)
    )

    active_rule_set = run_aws_text(
        [
            "ses",
            "describe-active-receipt-rule-set",
            "--region",
            region,
            "--query",
            "Metadata.Name",
        ]
    )
    if active_rule_set in {"None", "null", ""}:
        active_rule_set = "none"

    lambda_configuration = run_aws_json(
        ["lambda", "get-function", "--region", region, "--function-name", lambda_name]
    )["Configuration"]
    bucket_region = run_aws_text(
        [
            "s3api",
            "get-bucket-location",
            "--bucket",
            bucket_name,
            "--query",
            "LocationConstraint",
        ]
    )
    bucket_region = "us-east-1" if bucket_region == "None" else bucket_region
    invocation_sum_24h = get_metric_sum(region, lambda_name, "Invocations", 24)
    error_sum_24h = get_metric_sum(region, lambda_name, "Errors", 24)

    failures = []
    warnings = []
    rows = []

    if not production_enabled:
        failures.append("SES production access is not enabled.")

    if active_rule_set != expected_rule_set_name:
        failures.append(
            f"Active receipt rule set is '{active_rule_set}', expected '{expected_rule_set_name}'."
        )

    if bucket_region != region:
        failures.append(
            f"Shared inbound bucket is in region '{bucket_region}', expected '{region}'."
        )

    if error_sum_24h > 0:
        warnings.append(f"Lambda reported {error_sum_24h} error(s) in the last 24h.")

    if invocation_sum_24h == 0:
        warnings.append("Lambda reported zero invocations in the last 24h.")

    for domain in selected_domains:
        verification_status = run_aws_text(
            [
                "ses",
                "get-identity-verification-attributes",
                "--region",
                region,
                "--identities",
                domain,
                "--query",
                f"VerificationAttributes.\"{domain}\".VerificationStatus",
            ]
        )
        dkim_enabled = run_aws_text(
            [
                "ses",
                "get-identity-dkim-attributes",
                "--region",
                region,
                "--identities",
                domain,
                "--query",
                f"DkimAttributes.\"{domain}\".DkimEnabled",
            ]
        )
        dkim_status = run_aws_text(
            [
                "ses",
                "get-identity-dkim-attributes",
                "--region",
                region,
                "--identities",
                domain,
                "--query",
                f"DkimAttributes.\"{domain}\".DkimVerificationStatus",
            ]
        )
        receipt_rule = run_aws_json(
            [
                "ses",
                "describe-receipt-rule",
                "--region",
                region,
                "--rule-set-name",
                expected_rule_set_name,
                "--rule-name",
                rule_name_for_domain(domain),
            ]
        )["Rule"]
        target_nameservers = normalize_nameservers(
            domain_hosted_zones[domain]["name_servers"]
        )
        registered_nameservers = normalize_nameservers(
            [
                entry["Name"]
                for entry in run_aws_json(
                    [
                        "route53domains",
                        "get-domain-detail",
                        "--region",
                        "us-east-1",
                        "--domain-name",
                        domain,
                    ]
                )["Nameservers"]
            ]
        )

        rule_enabled = bool(receipt_rule.get("Enabled", False))
        nameservers_match = target_nameservers == registered_nameservers

        if verification_status != "Success":
            failures.append(
                f"{domain}: SES verification status is '{verification_status}', expected 'Success'."
            )
        if not normalize_bool(dkim_enabled):
            failures.append(f"{domain}: DKIM is not enabled.")
        if dkim_status != "Success":
            failures.append(
                f"{domain}: DKIM verification status is '{dkim_status}', expected 'Success'."
            )
        if not rule_enabled:
            failures.append(f"{domain}: SES receipt rule is disabled.")
        if not nameservers_match:
            failures.append(f"{domain}: registered nameservers do not match target zone.")

        rows.append(
            {
                "domain": domain,
                "verification_status": verification_status,
                "dkim_enabled": dkim_enabled,
                "dkim_status": dkim_status,
                "rule_enabled": "true" if rule_enabled else "false",
                "nameservers_match": "true" if nameservers_match else "false",
            }
        )

    summary_lines = [
        "## Post-Cutover Smoke Test",
        "",
        f"- Requested domain scope: `{requested_domain or 'all enabled domains'}`",
        f"- SES region: `{region}`",
        f"- Shared inbound bucket: `{bucket_name}`",
        f"- Shared inbound bucket region: `{bucket_region}`",
        f"- Forwarder Lambda: `{lambda_name}`",
        f"- Forwarder runtime: `{lambda_configuration['Runtime']}`",
        f"- Forwarder last modified: `{lambda_configuration['LastModified']}`",
        f"- SES production access enabled: `{str(production_enabled).lower()}`",
        f"- Active SES receipt rule set: `{active_rule_set}`",
        f"- Expected SES receipt rule set: `{expected_rule_set_name}`",
        f"- Lambda invocations (24h): `{invocation_sum_24h}`",
        f"- Lambda errors (24h): `{error_sum_24h}`",
        "",
        "| Domain | SES Verified | DKIM Enabled | DKIM Status | Receipt Rule Enabled | Nameservers Match |",
        "| --- | --- | --- | --- | --- | --- |",
    ]

    for row in rows:
        summary_lines.append(
            "| {domain} | {verification_status} | {dkim_enabled} | {dkim_status} | {rule_enabled} | {nameservers_match} |".format(
                **row
            )
        )

    if warnings:
        summary_lines.extend(["", "### Warnings", ""])
        summary_lines.extend(f"- {warning}" for warning in warnings)

    if failures:
        summary_lines.extend(["", "### Failures", ""])
        summary_lines.extend(f"- {failure}" for failure in failures)
    else:
        summary_lines.extend(["", "All smoke-test checks passed."])

    append_summary(summary_lines)
    print("\n".join(summary_lines))

    if failures:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
