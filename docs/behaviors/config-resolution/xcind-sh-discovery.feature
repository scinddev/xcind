# This feature verifies behaviors from:
# See: ../../specs/context-detection.md

Feature: .xcind.sh Discovery
  As a developer using xcind
  I want xcind to automatically find my project's .xcind.sh file
  So that I can run commands from any subdirectory within my project

  Scenario: Find .xcind.sh in the current directory
    Given a directory with a .xcind.sh file
    When xcind resolves the application root from that directory
    Then the application root is that directory

  Scenario: Walk upward from a nested subdirectory
    Given a directory with a .xcind.sh file
    And a deeply nested subdirectory within that directory
    When xcind resolves the application root from the nested subdirectory
    Then the application root is the directory containing .xcind.sh

  Scenario: Override with XCIND_APP_ROOT environment variable
    Given a directory with a .xcind.sh file
    And the XCIND_APP_ROOT environment variable is set to a different directory
    When xcind resolves the application root
    Then the application root is the XCIND_APP_ROOT value
    And the upward walk is skipped

  Scenario: Fail when no .xcind.sh exists
    Given a directory tree with no .xcind.sh file
    When xcind resolves the application root
    Then the resolution fails with exit code 1

  Scenario: Skip workspace directory when walking upward
    Given a workspace directory with a .xcind.sh that sets XCIND_IS_WORKSPACE=1
    And an app directory nested within the workspace
    When xcind resolves the application root from the app directory
    Then the walk stops at the app's .xcind.sh
    And the workspace .xcind.sh is not treated as the app root

  Scenario: Fail when only a workspace .xcind.sh exists above
    Given a workspace directory with a .xcind.sh that sets XCIND_IS_WORKSPACE=1
    And a subdirectory with no app-level .xcind.sh
    When xcind resolves the application root from the subdirectory
    Then the resolution fails with exit code 1
