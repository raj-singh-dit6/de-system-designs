import hashlib
import sys
import tempfile
import unittest
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1] / "src"))
from process_applications import process_batches, transform_row  # noqa: E402


class ApplicationProcessingTests(unittest.TestCase):
    def test_valid_application_is_transformed_and_assigned_membership_id(self):
        successful, row = transform_row(
            {"name": "Dr. Ada Lovelace", "email": "Ada@EMAILPROVIDER.COM", "date_of_birth": "1815-12-10", "mobile_no": "12345678"}
        )

        expected_hash = hashlib.sha256(b"18151210").hexdigest()[:5]
        self.assertTrue(successful)
        self.assertEqual("Ada", row["first_name"])
        self.assertEqual("Lovelace", row["last_name"])
        self.assertEqual("18151210", row["date_of_birth"])
        self.assertEqual("true", row["above_18"])
        self.assertEqual(f"Lovelace_{expected_hash}", row["membership_id"])

    def test_invalid_values_are_routed_with_all_rejection_reasons(self):
        successful, row = transform_row(
            {"name": "", "email": "not-an-allowed-domain@example.org", "date_of_birth": "not-a-date", "mobile_no": "123"}
        )

        self.assertFalse(successful)
        self.assertEqual("missing_name;invalid_email;invalid_mobile;invalid_birthdate", row["validation_errors"])
        self.assertEqual("", row["membership_id"])

    def test_exactly_18_on_reference_date_is_eligible(self):
        successful, row = transform_row(
            {"name": "Jane Doe", "email": "jane@emailprovider.net", "date_of_birth": "2004/01/01", "mobile_no": "87654321"}
        )

        self.assertTrue(successful)
        self.assertEqual("true", row["above_18"])

    def test_any_email_provider_with_com_or_net_suffix_is_accepted(self):
        successful, row = transform_row(
            {"name": "Jane Doe", "email": "jane@custom-provider.com", "date_of_birth": "1990-01-01", "mobile_no": "87654321"}
        )

        self.assertTrue(successful)
        self.assertEqual("", row["validation_errors"])

    def test_process_batches_writes_separate_consolidated_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            input_directory = root / "input"
            input_directory.mkdir()
            (input_directory / "a.csv").write_text(
                "name,email,date_of_birth,mobile_no\nJane Doe,jane@emailprovider.com,1990-01-01,12345678\n",
                encoding="utf-8",
            )
            (input_directory / "b.csv").write_text(
                "name,email,date_of_birth,mobile_no\nJohn Doe,john@example.com,2010-01-01,12345678\n",
                encoding="utf-8",
            )

            result = process_batches(input_directory, root / "output")

            self.assertEqual(1, result.successful_count)
            self.assertEqual(1, result.unsuccessful_count)
            self.assertTrue((root / "output/successful/successful_applications.csv").exists())
            self.assertTrue((root / "output/unsuccessful/unsuccessful_applications.csv").exists())


if __name__ == "__main__":
    unittest.main()
