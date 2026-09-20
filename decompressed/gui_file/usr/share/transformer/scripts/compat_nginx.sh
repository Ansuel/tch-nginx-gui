#!/bin/sh

# TG-1/VANT-5 firmware ships an older nginx/lua module without the
# init_worker_by_lua directive or SSL support.  Keep the standard config for
# every other device and only adapt it when the legacy binary rejects it.

nginx_config="${NGINX_CONFIG:-/etc/nginx/nginx.conf}"
nginx_bin="${NGINX_BIN:-nginx}"

is_legacy_tg1() {
  [ "${FORCE_LEGACY_NGINX:-0}" = "1" ] && return 0

  device_id="$(uci get -q env.var.prod_friendly_name) $(uci get -q env.var.prod_name) $(uci get -q env.rip.board_mnemonic)"
  case "$device_id" in
    *TG-1* | *TG1* | *VANT-5* | *VANT5*) return 0 ;;
  esac
  return 1
}

validate_nginx() {
  nginx_error="$("$nginx_bin" -t -c "$nginx_config" 2>&1)"
}

move_worker_initialization_to_init() {
  awk '
    /^[[:space:]]*init_worker_by_lua[[:space:]]/ {
      skip_worker = 1
      next
    }
    skip_worker {
      if ($0 ~ /^[[:space:]]*'\'';[[:space:]]*$/) skip_worker = 0
      next
    }
    /^[[:space:]]*init_by_lua[[:space:]]/ { in_init = 1 }
    in_init && /^[[:space:]]*'\'';[[:space:]]*$/ {
      print "\t\tlocal sessioncontrol = require(\"web.sessioncontrol\")"
      print "\t\tsessioncontrol.setManagerForPort(\"default\", \"80\")"
      print "\t\tsessioncontrol.setManagerForPort(\"default\", \"443\")"
      print "\t\tsessioncontrol.setManagerForPort(\"assistance\", \"8443\")"
      in_init = 0
    }
    { print }
  ' "$nginx_config" > "$nginx_config.modgui-new" && mv "$nginx_config.modgui-new" "$nginx_config"
}

disable_unsupported_ssl() {
  awk '
    /^[[:space:]]*listen[[:space:]].*[[:space:]]ssl;[[:space:]]*$/ { next }
    /^[[:space:]]*ssl_[[:alnum:]_]*[[:space:]].*;[[:space:]]*$/ { next }
    { print }
  ' "$nginx_config" > "$nginx_config.modgui-new" && mv "$nginx_config.modgui-new" "$nginx_config"
}

replace_unsupported_error_log() {
  awk '
    /^[[:space:]]*error_log[[:space:]].*;[[:space:]]*$/ {
      print "error_log /dev/null;"
      next
    }
    { print }
  ' "$nginx_config" > "$nginx_config.modgui-new" && mv "$nginx_config.modgui-new" "$nginx_config"
}

is_legacy_tg1 || exit 0
[ -f "$nginx_config" ] || exit 0

validate_nginx && exit 0

cp "$nginx_config" "$nginx_config.modgui-backup" || exit 1

rollback_nginx_config() {
  mv "$nginx_config.modgui-backup" "$nginx_config"
  rm -f "$nginx_config.modgui-new"
  exit 1
}

case "$nginx_error" in
  *'unknown directive "init_worker_by_lua"'*)
    move_worker_initialization_to_init || rollback_nginx_config
    validate_nginx
    ;;
esac

case "$nginx_error" in
  *'"ssl" parameter requires ngx_http_ssl_module'* | \
  *'unknown directive "ssl_'* | \
  *'unknown directive "ssl"'*)
    disable_unsupported_ssl
    validate_nginx
    ;;
esac

case "$nginx_error" in
  *error_log* | *syslog* | *facility=daemon* | *nohostname*)
    replace_unsupported_error_log
    validate_nginx
    ;;
esac

if validate_nginx; then
  rm "$nginx_config.modgui-backup"
  exit 0
fi

echo "Legacy nginx compatibility failed: $nginx_error" >&2
rollback_nginx_config
