#!/usr/bin/env python3

import json
import os
import sys


def load_plan(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def get_summary(plan):
    return (
        plan.get("planned_values", {})
        .get("outputs", {})
        .get("domain_plan_summary", {})
        .get("value", {})
    )


def render_lines(summary):
    lines = [
        "## Domain Plan Summary",
        "",
    ]

    if not summary:
        lines.extend(
            [
                "No enabled domains were found in `domain_plan_summary`.",
                "",
            ]
        )
        return lines

    for domain in sorted(summary.keys()):
        config = summary[domain]
        lines.extend(
            [
                f"### `{domain}`",
                f"- Receipt rule enabled: `{str(config['receipt_rule_enabled']).lower()}`",
                f"- Catch-all enabled: `{str(config['catch_all_enabled']).lower()}`",
                f"- Explicit recipient count: `{config['explicit_recipient_count']}`",
                f"- Forwarding destination count: `{config['forwarding_destination_count']}`",
                f"- Forwarding destinations: `{', '.join(config['forwarding_destinations'])}`",
                f"- Sender identity: `{config['sender_identity']}`",
                f"- S3 object prefix: `{config['s3_object_prefix']}`",
                f"- Preserved DNS record count: `{config['extra_record_count']}`",
                f"- Source DNS verification enabled: `{str(config['source_dns_verification_enabled']).lower()}`",
                f"- Preserved source verification token count: `{config['source_dns_token_count']}`",
                "",
            ]
        )

    return lines


def append_summary(lines):
    summary_path = os.getenv("GITHUB_STEP_SUMMARY")
    if not summary_path:
        sys.stdout.write("\n".join(lines))
        sys.stdout.write("\n")
        return

    with open(summary_path, "a", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
        handle.write("\n")


def main():
    if len(sys.argv) != 2:
        print("Usage: render_domain_plan_summary.py <terraform-plan-json>", file=sys.stderr)
        return 2

    plan = load_plan(sys.argv[1])
    append_summary(render_lines(get_summary(plan)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
