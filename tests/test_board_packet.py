import sys
from pathlib import Path
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from capture_board_test import parse_packet

class BoardPacketTests(unittest.TestCase):
    def test_pass_packet(self):
        data=parse_packet('TS1,P,00,00123456,00765432\r\n')
        self.assertTrue(data['passed'])
        self.assertEqual(data['provision_cycles'],0x123456)
        self.assertEqual(data['sign_cycles'],0x765432)

    def test_fail_packet(self):
        data=parse_packet('TS1,F,FF,00000000,00000000')
        self.assertFalse(data['passed'])
        self.assertEqual(data['failure_code'],255)

    def test_reject_corrupt_or_inconsistent(self):
        for line in ['TS1,P,01,00123456,00765432','TS1,P,00,00000000,00000001',
                     'TS1,F,00,00000000,00000000','TS1,P,00,00000001','garbage']:
            with self.subTest(line=line),self.assertRaises(ValueError): parse_packet(line)
