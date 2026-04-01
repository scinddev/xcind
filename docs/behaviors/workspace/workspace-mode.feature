# This feature verifies behaviors from:
# See: ../../specs/workspace-lifecycle.md

Feature: Workspace Mode
  As a developer using xcind
  I want xcind to detect when my app is inside a workspace
  So that services across apps can communicate on a shared network

  # --- Workspace Discovery ---

  Scenario: Detect workspace from parent .xcind.sh
    Given a workspace directory with a .xcind.sh that sets XCIND_IS_WORKSPACE=1
    And an app directory nested within the workspace with its own .xcind.sh
    When xcind discovers the workspace context from the app directory
    Then XCIND_WORKSPACE is set to the workspace directory basename
    And XCIND_WORKSPACE_ROOT is set to the workspace directory path
    And XCIND_WORKSPACELESS is 0

  Scenario: No workspace when parent lacks XCIND_IS_WORKSPACE
    Given a parent directory with a .xcind.sh that does not set XCIND_IS_WORKSPACE=1
    And an app directory nested within that parent with its own .xcind.sh
    When xcind discovers the workspace context from the app directory
    Then XCIND_WORKSPACELESS is 1
    And XCIND_WORKSPACE is empty

  Scenario: No workspace when no parent .xcind.sh exists
    Given a standalone app directory with a .xcind.sh
    And no parent directory has a .xcind.sh
    When xcind discovers the workspace context
    Then XCIND_WORKSPACELESS is 1

  # --- Workspace .xcind.sh Sourcing ---

  Scenario: Workspace .xcind.sh is sourced before app .xcind.sh
    Given a workspace .xcind.sh that sets XCIND_PROXY_DOMAIN="workspace.test"
    And an app .xcind.sh that does not override XCIND_PROXY_DOMAIN
    When xcind loads the full configuration
    Then XCIND_PROXY_DOMAIN is "workspace.test"

  Scenario: App .xcind.sh can override workspace settings
    Given a workspace .xcind.sh that sets XCIND_PROXY_DOMAIN="workspace.test"
    And an app .xcind.sh that sets XCIND_PROXY_DOMAIN="app.test"
    When xcind loads the full configuration
    Then XCIND_PROXY_DOMAIN is "app.test"
