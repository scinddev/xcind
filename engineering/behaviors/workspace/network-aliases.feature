# This feature verifies behaviors from:
# See: ../../specs/workspace-lifecycle.md

Feature: Workspace Network Aliases
  As a developer using xcind workspaces
  I want services to have predictable network aliases within the workspace
  So that apps can reference each other's services by name

  Background:
    Given a workspace named "dev"
    And an application named "frontend" with services "web", "worker", and "postgres"
    And XCIND_WORKSPACELESS is 0

  Scenario: Services get workspace-scoped aliases
    When xcind-workspace-hook generates the compose overlay
    Then the generated compose.workspace.yaml contains aliases:
      | Service  | Alias             |
      | web      | frontend-web      |
      | worker   | frontend-worker   |
      | postgres | frontend-postgres |

  Scenario: Workspace-internal network is created
    When xcind-workspace-hook generates the compose overlay
    Then the generated YAML creates a "dev-internal" network
    And all services are connected to the "dev-internal" network

  Scenario: Custom service template is applied
    Given XCIND_WORKSPACE_SERVICE_TEMPLATE is set to a custom template
    When xcind-workspace-hook generates the compose overlay
    Then the service aliases use the custom template

  Scenario: Hook returns compose file flag
    When xcind-workspace-hook is called
    Then the hook prints a "-f" flag pointing to compose.workspace.yaml

  Scenario: Hook is skipped in workspaceless mode
    Given XCIND_WORKSPACELESS is 1
    When xcind-workspace-hook is called
    Then no output is produced
    And no compose.workspace.yaml is generated
