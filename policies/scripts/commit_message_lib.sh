#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: commit_message_lib.sh
# DESCRIPTION: Shared commit subject validation and semver bump classification.
# VERSION: 1.3.0
# EXIT_CODES/SIGNALS: Sourced only; functions return 0/1 or print values.
# AUTHORS: DevOps Team
# =============================================================================
# Supported subject patterns (ticket = sctask<number>, inc<number>, DCDT-<number>):
#   1) TICKET keyword(scope): message
#   2) TICKET: keyword(scope) message
#   3) TICKET: keyword() message
#   4) TICKET keyword(): message
# Keywords: feat, fix, chore, docs, refactor, perf, test, style

COMMIT_MSG_KEYWORDS=(feat fix chore docs refactor perf test style)
COMMIT_MSG_SEMVER_MINOR_TYPES=(feat)
COMMIT_MSG_SEMVER_PATCH_TYPES=(fix chore)
COMMIT_MSG_VALID_NON_BUMP_TYPES=(docs refactor perf test style)
readonly COMMIT_MSG_TICKET_REGEX='([sS][cC][tT][aA][sS][kK][0-9]+|[iI][nN][cC][0-9]+|[dD][cC][dD][tT]-[0-9]+)'

# shellcheck disable=SC2329
_commit_msg_keywords_csv() {
  # INTENT: Print allowed keywords as a comma-separated list for help text.
  # INPUT: none.
  # OUTPUT: keyword list on stdout.
  # SIDE_EFFECTS: none.
  local IFS=', '
  printf '%s' "${COMMIT_MSG_KEYWORDS[*]}"
}

# shellcheck disable=SC2329
commit_msg_has_ticket_prefix() {
  # INTENT: Return whether the subject starts with an allowed ticket reference.
  # INPUT: subject line string.
  # OUTPUT: 0 if ticket prefix present, 1 otherwise.
  # SIDE_EFFECTS: none.
  local subject="$1"
  [[ "${subject}" =~ ^${COMMIT_MSG_TICKET_REGEX}[[:space:]]+ ]] && return 0
  [[ "${subject}" =~ ^${COMMIT_MSG_TICKET_REGEX}:[[:space:]]* ]] && return 0
  return 1
}

# shellcheck disable=SC2329
commit_msg_strip_ticket_prefix() {
  # INTENT: Remove the leading ticket token (with optional colon) from a commit subject.
  # INPUT: subject line string.
  # OUTPUT: body after ticket printed to stdout.
  # SIDE_EFFECTS: none.
  local subject="$1"
  if [[ "${subject}" =~ ^${COMMIT_MSG_TICKET_REGEX}[[:space:]]+(.+)$ ]]; then
    printf '%s' "${BASH_REMATCH[2]}"
    return 0
  fi
  if [[ "${subject}" =~ ^${COMMIT_MSG_TICKET_REGEX}:[[:space:]]*(.+)$ ]]; then
    printf '%s' "${BASH_REMATCH[2]}"
    return 0
  fi
  printf '%s' "${subject}"
}

# shellcheck disable=SC2329
_commit_body_matches_keyword() {
  # INTENT: Match keyword in one of the four supported body formats.
  # INPUT: body string; keyword token (e.g. feat, fix).
  # OUTPUT: 0 on match, 1 otherwise.
  # SIDE_EFFECTS: none.
  local body="$1"
  local keyword="$2"
  local scoped="^${keyword}(\\([^)]*\\))?[[:space:]]*:"
  local spaced="^${keyword}(\\([^)]*\\))?[[:space:]]+[^[:space:]:]"

  [[ "${body}" =~ ${scoped} ]] && return 0
  [[ "${body}" =~ ${spaced} ]] && return 0
  return 1
}

# shellcheck disable=SC2329
commit_msg_has_conventional_type() {
  # INTENT: Return whether the body uses an allowed conventional keyword.
  # INPUT: body after ticket prefix.
  # OUTPUT: 0 if type is recognized, 1 otherwise.
  # SIDE_EFFECTS: none.
  local body="$1"
  local t

  for t in "${COMMIT_MSG_KEYWORDS[@]}"; do
    if _commit_body_matches_keyword "${body}" "${t}"; then
      return 0
    fi
  done
  return 1
}

# shellcheck disable=SC2329
commit_msg_classify_semver_bump() {
  # INTENT: Map a conventional commit body to semver bump behavior.
  # INPUT: body after ticket prefix.
  # OUTPUT: prints minor|patch|skip|none.
  # SIDE_EFFECTS: none.
  local body="$1"
  local t

  for t in "${COMMIT_MSG_VALID_NON_BUMP_TYPES[@]}"; do
    if _commit_body_matches_keyword "${body}" "${t}"; then
      printf 'skip'
      return 0
    fi
  done

  for t in "${COMMIT_MSG_SEMVER_MINOR_TYPES[@]}"; do
    if _commit_body_matches_keyword "${body}" "${t}"; then
      printf 'minor'
      return 0
    fi
  done

  for t in "${COMMIT_MSG_SEMVER_PATCH_TYPES[@]}"; do
    if _commit_body_matches_keyword "${body}" "${t}"; then
      printf 'patch'
      return 0
    fi
  done

  printf 'none'
}

# shellcheck disable=SC2329
commit_msg_validate_subject() {
  # INTENT: Validate ticket prefix and conventional keyword on a commit subject.
  # INPUT: subject line string.
  # OUTPUT: 0 if valid, 1 if invalid (messages on stderr).
  # SIDE_EFFECTS: writes validation errors to stderr.
  local subject="$1"
  local body=""
  local keywords=""

  if [[ -z "${subject//[[:space:]]/}" ]]; then
    printf '%s\n' "Commit subject is empty." >&2
    return 1
  fi

  if [[ "${subject}" =~ ^Merge[[:space:]] ]]; then
    return 0
  fi

  if ! commit_msg_has_ticket_prefix "${subject}"; then
    printf '%s\n' \
      "Commit subject must start with a ticket: sctask<number>, inc<number>, or DCDT-<number>." \
      "Optional colon after ticket is allowed." \
      "Examples:" \
      "  DCDT-1234 feat(release): add hook" \
      "  SCTASK1234: fix(janitor) correct path" >&2
    return 1
  fi

  body="$(commit_msg_strip_ticket_prefix "${subject}")"
  if ! commit_msg_has_conventional_type "${body}"; then
    keywords="$(_commit_msg_keywords_csv)"
    printf '%s\n' \
      "Commit subject must use a supported keyword after the ticket." \
      "Formats:" \
      "  1) TICKET keyword(scope): message" \
      "  2) TICKET: keyword(scope) message" \
      "  3) TICKET: keyword() message" \
      "  4) TICKET keyword(): message" \
      "Keywords: ${keywords}." >&2
    return 1
  fi

  return 0
}

# shellcheck disable=SC2329
commit_msg_format_hint() {
  # INTENT: Print the canonical commit subject format for help text.
  # INPUT: none.
  # OUTPUT: format string printed to stdout.
  # SIDE_EFFECTS: none.
  printf '%s' "TICKET keyword(scope): msg | TICKET: keyword(scope) msg | TICKET: keyword() msg | TICKET keyword(): msg"
}
