"""Exercise the Eco settings against the pwrctl interfaces used by routers."""
import os
from pathlib import Path
import subprocess
import unittest

POWER = Path(__file__).resolve().parents[1] / 'decompressed/gui_file/etc/init.d/power'

LEGACY_HELP = '''pwrctl config ...
    --autogreeen on|off
    --eee on|off
    --ethapd on|off
    --wait on|off
    --cpuspeed [speed]
'''
MODERN_HELP = '''pwrctl config ...
    --eee on|off [ifname] : PHY EEE
    --apd on|off [ifname] : PHY APD
    --cpuwait on|off : CPU Wait
    --cpuspeed on|off [speed] : CPU Speed
pwrctl show ...
    --autogreeen : AutoGrEEEn
    --cpuspeed [speed] : CPU Speed
'''


class PowerInit(unittest.TestCase):
    def apply(self, help_text, *, speed='256', action='start', help_flag='help'):
        mock = r'''
cat() { printf '%s\n' 'Linux version 4.1'; }
config_load() { printf 'load %s\n' "$1"; }
config_get() {
    case "$2.$3" in
        cpu.cpuspeed) test_value=$SPEED ;;
        cpu.wait|ethernet.ethapd) test_value=0 ;;
        *) test_value=$4 ;;
    esac
    export "$1=$test_value"
}
pwrctl() {
    if [ "$1" = "$HELP_FLAG" ]; then
        printf '%s\n' "$HELP_TEXT" >&2
        return 1
    fi
    [ "$1" = config ] || return 1
    local IFS='|'
    printf '%s\n' "$*"
}
. "$POWER_SCRIPT"
"$ACTION"
'''
        result = subprocess.run(
            ['sh'], input=mock, text=True, capture_output=True, check=True,
            env=dict(os.environ, POWER_SCRIPT=str(POWER), ACTION=action,
                     SPEED=speed, HELP_FLAG=help_flag, HELP_TEXT=help_text),
        )
        self.assertEqual(result.stderr, '')
        self.assertEqual(result.stdout.splitlines()[0], 'load power')
        return result.stdout.splitlines()[1:]

    def test_legacy_syntax_and_fallback(self):
        for help_text in (LEGACY_HELP, ''):
            with self.subTest(help_text=help_text):
                self.assertEqual(self.apply(help_text), [
                    'config|--autogreeen|on', 'config|--eee|on', 'config|--ethapd|off',
                    'config|--wait|off', 'config|--cpuspeed|256',
                ])

    def test_modern_syntax_at_start_and_reload(self):
        for action in ('start', 'reload'):
            with self.subTest(action=action):
                self.assertEqual(self.apply(MODERN_HELP, action=action), [
                    'config|--eee|on', 'config|--apd|off', 'config|--cpuwait|off',
                    'config|--cpuspeed|on|256',
                ])

    def test_modern_cpu_speed_preserves_zero_and_handles_unset_speed(self):
        for speed, expected in (
            ('0', ['config|--cpuspeed|on|0']),
            ('4', ['config|--cpuspeed|on|4']),
            ('off', ['config|--cpuspeed|off']),
            ('', []),
        ):
            with self.subTest(speed=speed):
                self.assertEqual(self.apply(MODERN_HELP, speed=speed)[3:], expected)

    def test_partial_support_uses_exact_config_options(self):
        help_text = '''pwrctl config ...
    --eee-extra on|off
    --cpuwait on|off
pwrctl show ...
    --eee
    --cpuspeed
'''
        self.assertEqual(self.apply(help_text, help_flag='--help'), ['config|--cpuwait|off'])


if __name__ == '__main__':
    unittest.main()
