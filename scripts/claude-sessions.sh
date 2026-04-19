#!/bin/bash
# Claude Code Session Monitor
# Usage: claude-sessions.sh [--json]

JSON_MODE=false
[[ "$1" == "--json" ]] && JSON_MODE=true

count=0

if ! $JSON_MODE; then
  printf "%-6s  %-35s  %-8s  %-8s  %-10s  %s\n" "PID" "PROJECT" "CPU" "MEM" "STARTED" "ELAPSED"
  printf "%s\n" "$(printf '%.0s─' {1..90})"
fi

json_arr="["

while IFS= read -r line; do
  pid=$(echo "$line" | awk '{print $2}')
  cpu=$(echo "$line" | awk '{print $3}')
  mem=$(echo "$line" | awk '{print $4}')
  start=$(echo "$line" | awk '{print $9}')
  elapsed=$(echo "$line" | awk '{print $10}')
  args=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')

  # Get working directory
  cwd=$(lsof -p "$pid" -ad cwd -Fn 2>/dev/null | grep "^n" | sed 's/^n//')
  project=$(basename "$cwd" 2>/dev/null || echo "?")

  # Skip non-project dirs (plugin subdirs, empty)
  [[ -z "$cwd" ]] && continue
  [[ "$cwd" == *"/plugins/cache/"* ]] && continue

  # Resolve home dir to ~
  [[ "$cwd" == "$HOME" ]] && project="~"

  # Check for --resume with name
  resume_name=""
  if echo "$args" | grep -q "\-\-resume"; then
    resume_name=$(echo "$args" | sed -n 's/.*--resume \([^ ]*\).*/\1/p')
  fi

  # Check for --channels
  has_channels=false
  echo "$args" | grep -q "\-\-channels" && has_channels=true

  label="$project"
  [[ -n "$resume_name" && "$resume_name" != "--"* && ! "$resume_name" =~ ^[0-9a-f]{8}- ]] && label="$project ($resume_name)"

  count=$((count + 1))

  if $JSON_MODE; then
    [[ $count -gt 1 ]] && json_arr+=","
    json_arr+="{\"pid\":$pid,\"project\":\"$project\",\"cwd\":\"$cwd\",\"cpu\":\"$cpu%\",\"mem\":\"$mem%\",\"started\":\"$start\",\"elapsed\":\"$elapsed\",\"channels\":$has_channels,\"label\":\"$label\"}"
  else
    channels_icon=""
    $has_channels && channels_icon=" [TG]"
    printf "%-6s  %-35s  %-8s  %-8s  %-10s  %s%s\n" \
      "$pid" "$label" "$cpu%" "$mem%" "$start" "$elapsed" "$channels_icon"
  fi

done < <(ps aux | grep '[c]laude --' | grep -v bun)

if $JSON_MODE; then
  json_arr+="]"
  echo "$json_arr"
else
  printf "%s\n" "$(printf '%.0s─' {1..90})"
  echo "Total: $count sessions"
fi
