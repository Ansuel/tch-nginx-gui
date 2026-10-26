"""Synthetic Android snapshots; no captured device data is used."""
from pathlib import Path
import subprocess
import unittest

PARSER = Path(__file__).resolve().parents[1] / 'decompressed/smartphone/usr/share/modgui-smartphone/radio.awk'


def snapshot(eci=123456, pci=123, channel=1300, bands='', snr=-5):
    return f'''mDataConnectionState=2
mServiceState=mDataRegState=0(IN_SERVICE)
mSignalStrength=CellSignalStrengthLte: rsrp=-100 rsrq=-12 rssnr={snr}
mCellIdentity=CellIdentityLte:{{ mCi={eci} mPci={pci} mTac=100 mEarfcn={channel} mBands=[{bands}] mMcc=001 mMnc=01 }}
mPhysicalChannelConfigs=[{{mConnectionStatus=PrimaryServing,mNetworkType=LTE,mPhysicalCellId={pci},mBand=0}}]
'''


class RadioParserTest(unittest.TestCase):
    def parse(self, text, sdk=33):
        result = subprocess.run(['awk', '-v', 'mode=metrics', '-v', f'sdk={sdk}', '-f', str(PARSER)],
                                input=text, capture_output=True, text=True, check=True)
        return dict(line.split('|', 1) for line in result.stdout.splitlines())

    def test_identity_and_unknown_band_fallback(self):
        d = self.parse(snapshot())
        for key, value in {'BAND': 'B3', 'BAND_SOURCE': 'EARFCN', 'ENB': '482',
                           'SECTOR': '64', 'ECI': '123456', 'ECGI': '001-01-123456',
                           'TAC': '100', 'PCI': '123', 'SNR': '-5 dB'}.items():
            self.assertEqual(d[key], value, key)

    def test_current_active_sim_ignores_inactive_slot_and_history(self):
        text = 'Phone Id=0\n' + snapshot()
        text += 'Phone Id=1\nmDataConnectionState=-1\nmCellIdentity=null\n'
        text += 'mSignalStrength=CellSignalStrengthLte: rsrp=2147483647 rssnr=2147483647\n'
        text += 'mActiveDataSubId=7\nmDefaultSubId=7\nmDefaultPhoneId=0\n'
        text += 'local logs:\nPhone Id=0\n' + snapshot(eci=987654, snr=15)
        d = self.parse(text)
        self.assertEqual(d['SIM_SLOT'], '1')
        self.assertEqual(d['ECI'], '123456')
        self.assertEqual(d['SNR'], '-5 dB')

    def test_default_data_slot_wins_tied_connected_slots(self):
        d = self.parse('Phone Id=0\n' + snapshot() + 'Phone Id=1\n' + snapshot(eci=654321)
                       + 'mActiveDataSubId=8\nmDefaultSubId=8\nmDefaultPhoneId=1\n')
        self.assertEqual(d['SIM_SLOT'], '2')
        self.assertEqual(d['ECI'], '654321')

    def test_legacy_rssnr_uses_tenths(self):
        self.assertEqual(self.parse(snapshot(snr=-55), sdk=29)['SNR'], '-5.5 dB')
        self.assertEqual(self.parse(snapshot(snr=120), sdk=29)['SNR'], '12 dB')
        self.assertIn('scala Android non disponibile', self.parse(snapshot(), sdk=0)['SNR'])

    def test_zero_and_identity_boundaries(self):
        d = self.parse(snapshot(eci=0, pci=0, channel=0, snr=0))
        for key in ('ECI', 'ENB', 'SECTOR', 'PCI', 'EARFCN'):
            self.assertEqual(d[key], '0', key)
        self.assertEqual(d['SNR'], '0 dB')
        self.assertEqual(d['BAND'], 'B1')
        d = self.parse(snapshot(eci=268435455))
        self.assertEqual(d['ENB'], '1048575')
        self.assertEqual(d['SECTOR'], '255')

    def test_invalid_sentinels_do_not_become_metrics(self):
        d = self.parse(snapshot(eci=2147483647, pci=2147483647, channel=2147483647, snr=2147483647))
        for key in ('ECI', 'ENB', 'SECTOR', 'ECGI', 'PCI', 'EARFCN', 'BAND', 'SNR'):
            self.assertEqual(d[key], 'N/A', key)

    def test_band_ranges_and_gaps(self):
        for channel, band in ((6150, 'B20'), (6449, 'B20'), (6450, 'B21'),
                              (5280, 'B14'), (5379, 'B14'), (5380, 'N/A'),
                              (65536, 'B65'), (70645, 'B88'), (70646, 'N/A')):
            with self.subTest(channel=channel):
                self.assertEqual(self.parse(snapshot(channel=channel))['BAND'], band)

    def test_reported_bands_take_precedence(self):
        d = self.parse(snapshot(bands='7, 3'))
        self.assertEqual(d['BAND'], 'B7, B3')
        self.assertEqual(d['BAND_SOURCE'], 'Android')

    def test_registered_cell_fallback_ignores_neighbours(self):
        text = '''mCellInfo=[CellInfoLte:{mRegistered=YES CellIdentityLte:{mCi=123456 mPci=123 mTac=100 mEarfcn=1300} CellSignalStrengthLte: rsrp=-101 rsrq=-13 rssnr=-4}, CellInfoLte:{mRegistered=NO CellIdentityLte:{mCi=654321 mPci=321 mEarfcn=3000} CellSignalStrengthLte: rsrp=-80 rsrq=-8 rssnr=15}]
'''
        d = self.parse(text)
        self.assertEqual(d['ECI'], '123456')
        self.assertEqual(d['SNR'], '-4 dB')
        d = self.parse(snapshot() + text.replace('rssnr=-4', 'rssnr=2147483647'))
        self.assertEqual(d['SNR'], '-5 dB')

    def test_nr_primary_does_not_invent_lte_identity(self):
        text = 'mCellIdentity=CellIdentityNr:{ mNci=123456789 mPci=999 mTac=100 }\n'
        text += 'mCellInfo=[CellInfoLte:{mRegistered=YES CellIdentityLte:{mCi=123456 mPci=123 mTac=100 mEarfcn=1300}}]\n'
        text += 'mPhysicalChannelConfigs=[{mConnectionStatus=PrimaryServing,mNetworkType=NR,mPhysicalCellId=999,mBand=78}]\n'
        d = self.parse(text)
        for key in ('ECI', 'ENB', 'BAND', 'PCI'):
            self.assertEqual(d[key], 'N/A', key)

    def test_physical_lte_carrier_is_separate_from_nr(self):
        text = snapshot().split('mPhysicalChannelConfigs=')[0]
        text += 'mPhysicalChannelConfigs=[{mConnectionStatus=PrimaryServing,mNetworkType=LTE,mPhysicalCellId=123,mBand=3},{mConnectionStatus=PrimaryServing,mNetworkType=NR,mPhysicalCellId=999,mBand=78}]\n'
        self.assertEqual(self.parse(text)['BAND'], 'B3')


if __name__ == '__main__':
    unittest.main()
