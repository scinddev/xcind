# This feature verifies behaviors from:
# See: ../../specs/proxy-infrastructure.md

Feature: Proxy Hostname Generation
  As a developer using xcind
  I want hostnames to be generated from my proxy exports
  So that each service gets a predictable local URL

  Background:
    Given an application named "myapp"
    And XCIND_PROXY_DOMAIN is "localhost"

  # --- Workspaceless Mode ---

  Scenario: Simple export generates hostname
    Given XCIND_WORKSPACELESS is 1
    And XCIND_PROXY_EXPORTS contains "web"
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML contains hostname "myapp-web.localhost"

  Scenario: Export with explicit port
    Given XCIND_WORKSPACELESS is 1
    And XCIND_PROXY_EXPORTS contains "api:3000"
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML contains hostname "myapp-api.localhost"
    And the generated YAML routes to port 3000

  Scenario: Export with service name override
    Given XCIND_WORKSPACELESS is 1
    And XCIND_PROXY_EXPORTS contains "db=postgres:5432"
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML contains a "postgres" service block
    And the generated YAML contains hostname "myapp-db.localhost"
    And the generated YAML routes to port 5432

  # --- Workspace Mode ---

  Scenario: Workspace mode prefixes hostname with workspace name
    Given XCIND_WORKSPACELESS is 0
    And XCIND_WORKSPACE is "dev"
    And XCIND_PROXY_EXPORTS contains "web"
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML contains hostname "dev-myapp-web.localhost"

  Scenario: Workspace labels are set
    Given XCIND_WORKSPACELESS is 0
    And XCIND_WORKSPACE is "dev"
    And XCIND_WORKSPACE_ROOT is "/workspaces/dev"
    And XCIND_PROXY_EXPORTS contains "web"
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML contains label "xcind.workspace.name" with value "dev"
    And the generated YAML contains label "xcind.workspace.path" with value "/workspaces/dev"

  # --- Edge Cases ---

  Scenario: Empty exports produce no output
    Given XCIND_PROXY_EXPORTS is an empty array
    When xcind-proxy-hook is called
    Then no output is produced
    And no compose.proxy.yaml is generated

  Scenario: Unset exports produce no output
    Given XCIND_PROXY_EXPORTS is not set
    When xcind-proxy-hook is called
    Then no output is produced

  Scenario: Export referencing missing service fails
    Given XCIND_PROXY_EXPORTS contains "nonexistent"
    And no service named "nonexistent" exists in the resolved config
    When xcind-proxy-hook is called
    Then the hook exits with code 1
    And the error message contains "not found"
