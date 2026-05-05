# This feature verifies behaviors from:
# See: ../../specs/proxy-infrastructure.md

Feature: Apex URL Routing
  As a developer using xcind
  I want the first proxy export to receive an apex hostname
  So that my primary service gets a short, memorable URL

  Background:
    Given an application named "myapp"
    And XCIND_PROXY_DOMAIN is "localhost"

  # --- Workspaceless Apex ---

  Scenario: Primary export receives apex hostname
    Given XCIND_WORKSPACELESS is 1
    And XCIND_PROXY_EXPORTS contains "web" as the first entry
    And XCIND_APP_APEX_URL_TEMPLATE is the default
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML contains apex hostname "myapp.localhost"
    And the generated YAML contains label "xcind.apex.host" with value "myapp.localhost"
    And the generated YAML contains label "xcind.apex.url" with value "http://myapp.localhost"

  Scenario: Primary export retains its export hostname alongside apex
    Given XCIND_WORKSPACELESS is 1
    And XCIND_PROXY_EXPORTS contains "web" as the first entry
    And XCIND_APP_APEX_URL_TEMPLATE is the default
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML contains hostname "myapp-web.localhost"
    And the generated YAML contains apex hostname "myapp.localhost"

  Scenario: Non-primary exports do not receive apex hostname
    Given XCIND_WORKSPACELESS is 1
    And XCIND_PROXY_EXPORTS contains "web" and "api:3000"
    And XCIND_APP_APEX_URL_TEMPLATE is the default
    When xcind-proxy-hook generates the compose overlay
    Then the "api" service does not have label "xcind.apex.host"

  # --- Apex Opt-Out ---

  Scenario: Empty apex template disables apex routing
    Given XCIND_WORKSPACELESS is 1
    And XCIND_APP_APEX_URL_TEMPLATE is set to ""
    And XCIND_PROXY_EXPORTS contains "web"
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML does not contain label "xcind.apex.host"
    And the generated YAML does not contain label "xcind.apex.url"
    And the generated YAML still contains hostname "myapp-web.localhost"

  # --- Workspace Apex ---

  Scenario: Workspace apex hostname includes workspace prefix
    Given XCIND_WORKSPACELESS is 0
    And XCIND_WORKSPACE is "dev"
    And XCIND_PROXY_EXPORTS contains "web" as the first entry
    And XCIND_APP_APEX_URL_TEMPLATE is the default
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML contains apex hostname "dev-myapp.localhost"
    And the generated YAML contains label "xcind.apex.host" with value "dev-myapp.localhost"

  # --- Grouped Exports ---

  Scenario: Multiple exports on same service with apex
    Given XCIND_WORKSPACELESS is 1
    And XCIND_PROXY_EXPORTS contains "web=nginx:80" and "admin=nginx:443"
    And XCIND_APP_APEX_URL_TEMPLATE is the default
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML contains a single "nginx" service block
    And the generated YAML contains hostname "myapp-web.localhost"
    And the generated YAML contains hostname "myapp-admin.localhost"
    And the generated YAML contains apex hostname "myapp.localhost"
