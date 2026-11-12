"""Regression checks for GUI links that cannot rely on stock firmware files."""

from pathlib import Path
import re
import unittest


WWW = Path(__file__).resolve().parents[1] / "decompressed/gui_file/www"


class GuiAssetDependencies(unittest.TestCase):
    def test_newem_pages_bundle_their_native_assets_and_acl_targets(self):
        installer = (WWW.parent / 'usr/share/transformer/scripts/unlock_and_refresh_web_config.lua').read_text()
        for name in ('configuration', 'topology', 'devices-info'):
            filename = f'easymesh-{name}-modal-newEM.lp'
            source = (WWW / 'docroot/modals' / filename).read_text()
            self.assertIn('/modals/' + filename, installer)
            self.assertIn('mesh.use_new_layout()', source)
            for image in re.findall(r'[\w-]+\.png', source):
                self.assertTrue((WWW / 'docroot/img' / image).is_file(), image)
            for script in re.findall(r'src="/js/([^\"]+)"', source):
                self.assertTrue((WWW / 'docroot/js' / script).is_file(), script)
            self.assertNotIn('easymesh_view', source)
        self.assertFalse((WWW / 'lua/easymesh_view.lua').exists())
        self.assertFalse((WWW / 'docroot/css/easymesh.css').exists())

    def test_standalone_pages_do_not_request_missing_stock_bundle(self):
        for page in ("parental-block.lp", "password-reset.lp"):
            text = (WWW / "docroot" / page).read_text()
            self.assertNotIn('src="/js/main-min.js"', text)
        reset = (WWW / "docroot/password-reset.lp").read_text()
        self.assertIn('src="/js/jquery.min.js"', reset)

    def test_optional_easymesh_tabs_check_modal_availability(self):
        tabs = (WWW / "snippets/tabs-easyMesh.lp").read_text()
        for modal in ("agent-list.lp", "wifi-devices-info.lp"):
            self.assertIn(f'modal_available("{modal}")', tabs)

    def test_wireless_client_form_targets_existing_modal(self):
        modal = WWW / "docroot/modals/wireless-client-modal.lp"
        self.assertIn('action="modals/wireless-client-modal.lp"', modal.read_text())


if __name__ == "__main__":
    unittest.main()
