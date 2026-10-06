"""Regression checks for GUI links that cannot rely on stock firmware files."""

from pathlib import Path
import unittest


WWW = Path(__file__).resolve().parents[1] / "decompressed/gui_file/www"


class GuiAssetDependencies(unittest.TestCase):
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
