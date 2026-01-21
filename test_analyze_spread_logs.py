#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.
"""
Unit tests for the analyze-spread-logs tool.

These tests use sample spread log data to verify that the log parsing and
analysis functionality works correctly, preventing regressions during refactoring.
"""

import unittest
import sys
import io
from datetime import datetime
from pathlib import Path

# Import the module - we need to use exec to handle the hyphen in filename
import importlib.util

# Get the absolute path to the script
script_path = Path(__file__).parent / "bin" / "analyze-spread-logs"

# Read and execute the file content to import functions
with open(script_path, 'r') as f:
    script_content = f.read()

# Create a module namespace
analyze_module = type(sys)('analyze_spread_logs')

# Execute the script in the module's namespace
exec(script_content, analyze_module.__dict__)

# Add to sys.modules
sys.modules['analyze_spread_logs'] = analyze_module


class TestParseTimestamp(unittest.TestCase):
    """Test timestamp parsing functionality."""
    
    def test_parse_valid_timestamp(self):
        """Test parsing a valid timestamp."""
        line = "2026-01-13 11:10:26 Some log message"
        result = analyze_module.parse_timestamp(line)
        self.assertIsNotNone(result)
        self.assertEqual(result, datetime(2026, 1, 13, 11, 10, 26))
    
    def test_parse_invalid_timestamp(self):
        """Test parsing a line without a timestamp."""
        line = "This line has no timestamp"
        result = analyze_module.parse_timestamp(line)
        self.assertIsNone(result)
    
    def test_parse_empty_line(self):
        """Test parsing an empty line."""
        result = analyze_module.parse_timestamp("")
        self.assertIsNone(result)


class TestParseLogLine(unittest.TestCase):
    """Test log line parsing functionality."""
    
    def test_parse_preparing_phase(self):
        """Test parsing a Preparing phase log line."""
        line = "2026-01-13 11:15:15 Preparing garden:archlinux-cloud:tests/desktop/firefox (garden:archlinux-cloud)..."
        result = analyze_module.parse_log_line(line)
        self.assertIsNotNone(result)
        timestamp, phase, system, test_name = result
        self.assertEqual(timestamp, datetime(2026, 1, 13, 11, 15, 15))
        self.assertEqual(phase, "Preparing")
        self.assertEqual(system, "archlinux-cloud")
        self.assertEqual(test_name, "tests/desktop/firefox")
    
    def test_parse_executing_phase(self):
        """Test parsing an Executing phase log line."""
        line = "2026-01-13 11:16:13 Executing garden:archlinux-cloud:tests/desktop/firefox (garden:archlinux-cloud) (2/19)..."
        result = analyze_module.parse_log_line(line)
        self.assertIsNotNone(result)
        timestamp, phase, system, test_name = result
        self.assertEqual(timestamp, datetime(2026, 1, 13, 11, 16, 13))
        self.assertEqual(phase, "Executing")
        self.assertEqual(system, "archlinux-cloud")
        self.assertEqual(test_name, "tests/desktop/firefox")
    
    def test_parse_restoring_phase(self):
        """Test parsing a Restoring phase log line."""
        line = "2026-01-13 11:16:14 Restoring garden:archlinux-cloud:tests/desktop/firefox (garden:archlinux-cloud)..."
        result = analyze_module.parse_log_line(line)
        self.assertIsNotNone(result)
        timestamp, phase, system, test_name = result
        self.assertEqual(timestamp, datetime(2026, 1, 13, 11, 16, 14))
        self.assertEqual(phase, "Restoring")
        self.assertEqual(system, "archlinux-cloud")
        self.assertEqual(test_name, "tests/desktop/firefox")
    
    def test_parse_debugging_phase(self):
        """Test parsing a Debugging phase log line."""
        line = "2026-01-13 11:16:15 Debugging garden:archlinux-cloud:tests/desktop/firefox (garden:archlinux-cloud)..."
        result = analyze_module.parse_log_line(line)
        self.assertIsNotNone(result)
        timestamp, phase, system, test_name = result
        self.assertEqual(timestamp, datetime(2026, 1, 13, 11, 16, 15))
        self.assertEqual(phase, "Debugging")
        self.assertEqual(system, "archlinux-cloud")
        self.assertEqual(test_name, "tests/desktop/firefox")
    
    def test_parse_test_with_colon_in_name(self):
        """Test parsing a test name that contains colons."""
        line = "2026-01-13 11:15:17 Preparing garden:archlinux-cloud:tests/server/maas:3_6 (garden:archlinux-cloud)..."
        result = analyze_module.parse_log_line(line)
        self.assertIsNotNone(result)
        timestamp, phase, system, test_name = result
        self.assertEqual(test_name, "tests/server/maas:3_6")
    
    def test_parse_system_preparation_line(self):
        """Test that system preparation lines are not matched."""
        line = "2026-01-13 11:10:47 Preparing garden:archlinux-cloud (garden:archlinux-cloud)..."
        result = analyze_module.parse_log_line(line)
        self.assertIsNone(result)  # Should not match system prep, only test prep
    
    def test_parse_invalid_line(self):
        """Test parsing a line that doesn't match the pattern."""
        line = "2026-01-13 11:10:26 Found /home/runner/work/snapd-smoke-tests/snapd-smoke-tests/spread.yaml."
        result = analyze_module.parse_log_line(line)
        self.assertIsNone(result)


class TestAnalyzeLogs(unittest.TestCase):
    """Test log analysis functionality with sample data."""
    
    def setUp(self):
        """Set up sample log data for tests."""
        self.sample_log = """2026-01-13 11:10:26 Found /home/runner/work/snapd-smoke-tests/snapd-smoke-tests/spread.yaml.
2026-01-13 11:10:26 Project content is packed for delivery (22.33KB).
2026-01-13 11:10:26 Sequence of jobs produced with -seed=1768302626
2026-01-13 11:10:26 If killed, discard servers with: spread -reuse-pid=5121 -discard
2026-01-13 11:10:26 Allocating garden:archlinux-cloud...
2026-01-13 11:10:26 Allocating garden:archlinux-cloud...
2026-01-13 11:10:28 Waiting for garden:archlinux-cloud to make SSH available at localhost:8188...
2026-01-13 11:10:28 Allocated garden:archlinux-cloud.
2026-01-13 11:10:28 Connecting to garden:archlinux-cloud...
2026-01-13 11:10:29 Waiting for garden:archlinux-cloud to make SSH available at localhost:9400...
2026-01-13 11:10:29 Allocated garden:archlinux-cloud.
2026-01-13 11:10:29 Connecting to garden:archlinux-cloud...
2026-01-13 11:10:47 Connected to garden:archlinux-cloud at localhost:8188.
2026-01-13 11:10:47 Sending project content to garden:archlinux-cloud...
2026-01-13 11:10:47 Preparing garden:archlinux-cloud (garden:archlinux-cloud)...
2026-01-13 11:10:47 Connected to garden:archlinux-cloud at localhost:9400.
2026-01-13 11:10:47 Sending project content to garden:archlinux-cloud...
2026-01-13 11:10:48 Preparing garden:archlinux-cloud (garden:archlinux-cloud)...
2026-01-13 11:15:15 Preparing garden:archlinux-cloud:tests/desktop/firefox (garden:archlinux-cloud)...
2026-01-13 11:15:17 Preparing garden:archlinux-cloud:tests/server/maas:3_6 (garden:archlinux-cloud)...
2026-01-13 11:16:01 Executing garden:archlinux-cloud:tests/server/maas:3_6 (garden:archlinux-cloud) (1/19)...
2026-01-13 11:16:13 Executing garden:archlinux-cloud:tests/desktop/firefox (garden:archlinux-cloud) (2/19)...
2026-01-13 11:16:14 Restoring garden:archlinux-cloud:tests/desktop/firefox (garden:archlinux-cloud)...
2026-01-13 11:16:45 Preparing garden:archlinux-cloud:tests/desktop/spotify (garden:archlinux-cloud)...
2026-01-13 11:17:20 Executing garden:archlinux-cloud:tests/desktop/spotify (garden:archlinux-cloud) (3/19)...
2026-01-13 11:17:21 Restoring garden:archlinux-cloud:tests/desktop/spotify (garden:archlinux-cloud)..."""
    
    def test_analyze_sample_logs(self):
        """Test analyzing the sample log data."""
        tests = analyze_module.analyze_logs(self.sample_log)
        
        # Should find 3 tests
        self.assertEqual(len(tests), 3)
        
        # Check test names
        test_names = {test.test_name for test in tests}
        self.assertIn("tests/desktop/firefox", test_names)
        self.assertIn("tests/server/maas:3_6", test_names)
        self.assertIn("tests/desktop/spotify", test_names)
    
    def test_firefox_test_timing(self):
        """Test specific timing calculations for firefox test."""
        tests = analyze_module.analyze_logs(self.sample_log)
        firefox = next(t for t in tests if t.test_name == "tests/desktop/firefox")
        
        # Firefox should have all three phases
        self.assertIn("Preparing", firefox.phases)
        self.assertIn("Executing", firefox.phases)
        self.assertIn("Restoring", firefox.phases)
        
        # Check prepare duration (11:15:15 to 11:16:13 = 58 seconds)
        self.assertEqual(firefox.prepare_duration, 58.0)
        
        # Check execute duration (11:16:13 to 11:16:14 = 1 second)
        self.assertEqual(firefox.execute_duration, 1.0)
        
        # Check restore duration (11:16:14 to 11:16:45 when spotify prepares = 31 seconds)
        self.assertEqual(firefox.restore_duration, 31.0)
        
        # Check total duration (58 + 1 + 31 = 90 seconds)
        self.assertEqual(firefox.total_duration, 90.0)
    
    def test_maas_test_timing(self):
        """Test specific timing calculations for maas test."""
        tests = analyze_module.analyze_logs(self.sample_log)
        maas = next(t for t in tests if t.test_name == "tests/server/maas:3_6")
        
        # MAAS should have Preparing and Executing phases
        self.assertIn("Preparing", maas.phases)
        self.assertIn("Executing", maas.phases)
        
        # MAAS should NOT have Restoring phase in this log
        self.assertNotIn("Restoring", maas.phases)
        
        # Check prepare duration (11:15:17 to 11:16:01 = 44 seconds)
        self.assertEqual(maas.prepare_duration, 44.0)
        
        # Execute phase (11:16:01 to 11:16:13 when firefox executes = 12 seconds)
        self.assertEqual(maas.execute_duration, 12.0)
    
    def test_spotify_test_timing(self):
        """Test specific timing calculations for spotify test."""
        tests = analyze_module.analyze_logs(self.sample_log)
        spotify = next(t for t in tests if t.test_name == "tests/desktop/spotify")
        
        # Spotify should have all three phases
        self.assertIn("Preparing", spotify.phases)
        self.assertIn("Executing", spotify.phases)
        self.assertIn("Restoring", spotify.phases)
        
        # Check prepare duration (11:16:45 to 11:17:20 = 35 seconds)
        self.assertEqual(spotify.prepare_duration, 35.0)
        
        # Check execute duration (11:17:20 to 11:17:21 = 1 second)
        self.assertEqual(spotify.execute_duration, 1.0)
        
        # Restoring has no end time
        self.assertEqual(spotify.restore_duration, 0.0)
    
    def test_empty_log(self):
        """Test analyzing an empty log."""
        tests = analyze_module.analyze_logs("")
        self.assertEqual(len(tests), 0)
    
    def test_log_with_no_tests(self):
        """Test analyzing a log with no test entries."""
        log = """2026-01-13 11:10:26 Found spread.yaml.
2026-01-13 11:10:26 Project content is packed.
2026-01-13 11:10:47 Preparing garden:archlinux-cloud (garden:archlinux-cloud)..."""
        tests = analyze_module.analyze_logs(log)
        self.assertEqual(len(tests), 0)


class TestFormatDuration(unittest.TestCase):
    """Test duration formatting functionality."""
    
    def test_format_seconds(self):
        """Test formatting durations in seconds."""
        self.assertEqual(analyze_module.format_duration(0.5), "0.5s")
        self.assertEqual(analyze_module.format_duration(30.0), "30.0s")
        self.assertEqual(analyze_module.format_duration(59.9), "59.9s")
    
    def test_format_minutes(self):
        """Test formatting durations in minutes."""
        self.assertEqual(analyze_module.format_duration(60.0), "1m 0.0s")
        self.assertEqual(analyze_module.format_duration(90.5), "1m 30.5s")
        self.assertEqual(analyze_module.format_duration(3599.0), "59m 59.0s")
    
    def test_format_hours(self):
        """Test formatting durations in hours."""
        self.assertEqual(analyze_module.format_duration(3600.0), "1h 0m 0.0s")
        self.assertEqual(analyze_module.format_duration(3661.5), "1h 1m 1.5s")
        self.assertEqual(analyze_module.format_duration(7384.2), "2h 3m 4.2s")


class TestTestPhase(unittest.TestCase):
    """Test TestPhase dataclass functionality."""
    
    def test_duration_with_both_times(self):
        """Test duration calculation with start and end times."""
        phase = analyze_module.TestPhase("Preparing")
        phase.start_time = datetime(2026, 1, 13, 11, 15, 15)
        phase.end_time = datetime(2026, 1, 13, 11, 16, 13)
        self.assertEqual(phase.duration, 58.0)
    
    def test_duration_with_no_end_time(self):
        """Test duration when end time is missing."""
        phase = analyze_module.TestPhase("Preparing")
        phase.start_time = datetime(2026, 1, 13, 11, 15, 15)
        self.assertEqual(phase.duration, 0.0)
    
    def test_duration_with_no_start_time(self):
        """Test duration when start time is missing."""
        phase = analyze_module.TestPhase("Preparing")
        phase.end_time = datetime(2026, 1, 13, 11, 16, 13)
        self.assertEqual(phase.duration, 0.0)
    
    def test_duration_with_no_times(self):
        """Test duration when both times are missing."""
        phase = analyze_module.TestPhase("Preparing")
        self.assertEqual(phase.duration, 0.0)


class TestTestExecution(unittest.TestCase):
    """Test TestExecution dataclass functionality."""
    
    def test_total_duration(self):
        """Test total duration calculation across phases."""
        test = analyze_module.TestExecution("tests/desktop/firefox", "archlinux-cloud")
        
        # Add preparing phase
        prep_phase = analyze_module.TestPhase("Preparing")
        prep_phase.start_time = datetime(2026, 1, 13, 11, 15, 15)
        prep_phase.end_time = datetime(2026, 1, 13, 11, 16, 13)
        test.phases["Preparing"] = prep_phase
        
        # Add executing phase
        exec_phase = analyze_module.TestPhase("Executing")
        exec_phase.start_time = datetime(2026, 1, 13, 11, 16, 13)
        exec_phase.end_time = datetime(2026, 1, 13, 11, 16, 14)
        test.phases["Executing"] = exec_phase
        
        self.assertEqual(test.total_duration, 59.0)
    
    def test_prepare_duration_missing_phase(self):
        """Test prepare_duration when phase doesn't exist."""
        test = analyze_module.TestExecution("tests/desktop/firefox", "archlinux-cloud")
        self.assertEqual(test.prepare_duration, 0.0)
    
    def test_execute_duration_missing_phase(self):
        """Test execute_duration when phase doesn't exist."""
        test = analyze_module.TestExecution("tests/desktop/firefox", "archlinux-cloud")
        self.assertEqual(test.execute_duration, 0.0)
    
    def test_restore_duration_missing_phase(self):
        """Test restore_duration when phase doesn't exist."""
        test = analyze_module.TestExecution("tests/desktop/firefox", "archlinux-cloud")
        self.assertEqual(test.restore_duration, 0.0)
    
    def test_debug_duration_missing_phase(self):
        """Test debug_duration when phase doesn't exist."""
        test = analyze_module.TestExecution("tests/desktop/firefox", "archlinux-cloud")
        self.assertEqual(test.debug_duration, 0.0)


class TestPrintSummary(unittest.TestCase):
    """Test summary printing functionality."""
    
    def test_print_summary_with_tests(self):
        """Test printing summary with test data."""
        # Create test data
        test1 = analyze_module.TestExecution("tests/desktop/firefox", "archlinux-cloud")
        prep = analyze_module.TestPhase("Preparing")
        prep.start_time = datetime(2026, 1, 13, 11, 15, 15)
        prep.end_time = datetime(2026, 1, 13, 11, 16, 13)
        test1.phases["Preparing"] = prep
        
        # Capture output
        captured_output = io.StringIO()
        old_stdout = sys.stdout
        sys.stdout = captured_output
        
        try:
            analyze_module.print_summary([test1])
            output = captured_output.getvalue()
            
            # Check that output contains expected elements
            self.assertIn("Test Execution Time Analysis", output)
            self.assertIn("tests/desktop/firefox", output)
            self.assertIn("archlinux-cloud", output)
            self.assertIn("58.0s", output)
        finally:
            sys.stdout = old_stdout
    
    def test_print_summary_empty(self):
        """Test printing summary with no test data."""
        captured_output = io.StringIO()
        old_stdout = sys.stdout
        sys.stdout = captured_output
        
        try:
            analyze_module.print_summary([])
            output = captured_output.getvalue()
            self.assertIn("No test execution data found", output)
        finally:
            sys.stdout = old_stdout


class TestConcurrentExecution(unittest.TestCase):
    """Test handling of concurrent test execution."""
    
    def test_concurrent_tests(self):
        """Test parsing logs with concurrent test execution."""
        log = """2026-01-13 11:15:15 Preparing garden:archlinux-cloud:tests/desktop/firefox (garden:archlinux-cloud)...
2026-01-13 11:15:17 Preparing garden:archlinux-cloud:tests/server/maas:3_6 (garden:archlinux-cloud)...
2026-01-13 11:16:01 Executing garden:archlinux-cloud:tests/server/maas:3_6 (garden:archlinux-cloud) (1/19)...
2026-01-13 11:16:13 Executing garden:archlinux-cloud:tests/desktop/firefox (garden:archlinux-cloud) (2/19)..."""
        
        tests = analyze_module.analyze_logs(log)
        self.assertEqual(len(tests), 2)
        
        # Both tests should have their own independent timings
        firefox = next(t for t in tests if t.test_name == "tests/desktop/firefox")
        maas = next(t for t in tests if t.test_name == "tests/server/maas:3_6")
        
        # Firefox prepare: 11:15:15 to 11:16:13 = 58 seconds
        self.assertEqual(firefox.prepare_duration, 58.0)
        
        # MAAS prepare: 11:15:17 to 11:16:01 = 44 seconds
        self.assertEqual(maas.prepare_duration, 44.0)


class TestSequentialPhases(unittest.TestCase):
    """Test that phases execute sequentially within a test."""
    
    def test_failed_test_with_debug_phase(self):
        """Test a failed test that goes through all phases including Debugging."""
        log = """2026-01-13 11:15:15 Preparing garden:archlinux-cloud:tests/desktop/broken (garden:archlinux-cloud)...
2026-01-13 11:16:00 Executing garden:archlinux-cloud:tests/desktop/broken (garden:archlinux-cloud) (1/10)...
2026-01-13 11:16:05 Restoring garden:archlinux-cloud:tests/desktop/broken (garden:archlinux-cloud)...
2026-01-13 11:16:10 Debugging garden:archlinux-cloud:tests/desktop/broken (garden:archlinux-cloud)...
2026-01-13 11:16:20 Preparing garden:archlinux-cloud:tests/desktop/good (garden:archlinux-cloud)..."""
        
        tests = analyze_module.analyze_logs(log)
        broken_test = next(t for t in tests if t.test_name == "tests/desktop/broken")
        
        # Test should have all four phases
        self.assertIn("Preparing", broken_test.phases)
        self.assertIn("Executing", broken_test.phases)
        self.assertIn("Restoring", broken_test.phases)
        self.assertIn("Debugging", broken_test.phases)
        
        # Verify durations (phases execute sequentially within a test)
        # Preparing: 11:15:15 to 11:16:00 = 45 seconds
        self.assertEqual(broken_test.prepare_duration, 45.0)
        
        # Executing: 11:16:00 to 11:16:05 = 5 seconds
        self.assertEqual(broken_test.execute_duration, 5.0)
        
        # Restoring: 11:16:05 to 11:16:10 = 5 seconds
        self.assertEqual(broken_test.restore_duration, 5.0)
        
        # Debugging: 11:16:10 to 11:16:20 = 10 seconds (ends when next test starts)
        self.assertEqual(broken_test.debug_duration, 10.0)
        
        # Total: 45 + 5 + 5 + 10 = 65 seconds
        self.assertEqual(broken_test.total_duration, 65.0)
    
    def test_successful_test_without_debug_phase(self):
        """Test a successful test that does not have a Debugging phase."""
        log = """2026-01-13 11:15:15 Preparing garden:archlinux-cloud:tests/desktop/good (garden:archlinux-cloud)...
2026-01-13 11:16:00 Executing garden:archlinux-cloud:tests/desktop/good (garden:archlinux-cloud) (1/10)...
2026-01-13 11:16:05 Restoring garden:archlinux-cloud:tests/desktop/good (garden:archlinux-cloud)...
2026-01-13 11:16:10 Preparing garden:archlinux-cloud:tests/desktop/next (garden:archlinux-cloud)..."""
        
        tests = analyze_module.analyze_logs(log)
        good_test = next(t for t in tests if t.test_name == "tests/desktop/good")
        
        # Test should have three phases (no Debugging)
        self.assertIn("Preparing", good_test.phases)
        self.assertIn("Executing", good_test.phases)
        self.assertIn("Restoring", good_test.phases)
        self.assertNotIn("Debugging", good_test.phases)
        
        # Debug duration should be 0
        self.assertEqual(good_test.debug_duration, 0.0)
        
        # Preparing: 11:15:15 to 11:16:00 = 45 seconds
        self.assertEqual(good_test.prepare_duration, 45.0)
        # Executing: 11:16:00 to 11:16:05 = 5 seconds
        self.assertEqual(good_test.execute_duration, 5.0)
        # Restoring: 11:16:05 to 11:16:10 = 5 seconds (ends when next test starts preparing)
        self.assertEqual(good_test.restore_duration, 5.0)
        
        # Total should be 45 + 5 + 5 = 55 seconds
        self.assertEqual(good_test.total_duration, 55.0)


if __name__ == '__main__':
    unittest.main()
