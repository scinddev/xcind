# This feature verifies behaviors from:
# See: ../../specs/workspace-lifecycle.md

Feature: Workspace Self-Declaration
  As a developer using xcind
  I want an app to declare itself as part of a workspace
  So that workspace features activate even without a parent workspace .xcind.sh

  Scenario: App declares workspace via XCIND_WORKSPACE variable
    Given a standalone app .xcind.sh that sets XCIND_WORKSPACE="dev"
    And the app is not nested inside a workspace directory
    When xcind performs late-bind workspace resolution
    Then XCIND_WORKSPACELESS is set to 0
    And XCIND_WORKSPACE is "dev"
    And XCIND_WORKSPACE_ROOT is derived from XCIND_APP_ROOT

  Scenario: Late-bind is skipped when already in workspace mode
    Given an app inside a detected workspace
    And the app .xcind.sh also sets XCIND_WORKSPACE="other"
    When xcind performs late-bind workspace resolution
    Then the existing workspace context is preserved
    And XCIND_WORKSPACE retains the discovered value, not "other"

  Scenario: Late-bind is skipped when XCIND_WORKSPACE is empty
    Given a standalone app .xcind.sh that does not set XCIND_WORKSPACE
    When xcind performs late-bind workspace resolution
    Then XCIND_WORKSPACELESS remains 1
    And no workspace context is created
