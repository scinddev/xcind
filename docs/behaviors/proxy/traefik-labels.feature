# This feature verifies behaviors from:
# See: ../../specs/docker-labels.md
# See: ../../specs/proxy-infrastructure.md

Feature: Traefik Label Generation
  As a developer using xcind
  I want correct Traefik labels generated in my compose overlay
  So that the reverse proxy routes traffic to my services

  Background:
    Given an application named "myapp"
    And XCIND_PROXY_DOMAIN is "localhost"
    And XCIND_WORKSPACELESS is 1

  Scenario: Traefik is enabled on exported services
    Given XCIND_PROXY_EXPORTS contains "web"
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML contains label "traefik.enable" with value "true"

  Scenario: Router rule uses Host matcher
    Given XCIND_PROXY_EXPORTS contains "web"
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML contains a Traefik router named "myapp-web-http"
    And the router rule matches Host "myapp-web.localhost"

  Scenario: Service port is configured via loadbalancer
    Given XCIND_PROXY_EXPORTS contains "api:3000"
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML routes the "api" service to port 3000

  Scenario: Default port is inferred from resolved config
    Given XCIND_PROXY_EXPORTS contains "web" with no explicit port
    And the resolved Docker Compose config shows port 80 for the "web" service
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML routes the "web" service to port 80

  Scenario: App name label is set
    Given XCIND_PROXY_EXPORTS contains "web"
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML contains label "xcind.app.name" with value "myapp"

  Scenario: Export-specific host labels are set
    Given XCIND_PROXY_EXPORTS contains "web" and "db=postgres:5432"
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML contains label "xcind.export.web.host" with value "myapp-web.localhost"
    And the generated YAML contains label "xcind.export.db.host" with value "myapp-db.localhost"

  Scenario: Proxy network is attached
    Given XCIND_PROXY_EXPORTS contains "web"
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML connects the service to the "xcind-proxy" network
    And the "xcind-proxy" network is marked as external

  Scenario: Multiple exports on the same service produce a single block
    Given XCIND_PROXY_EXPORTS contains "web=nginx:80" and "admin=nginx:443"
    When xcind-proxy-hook generates the compose overlay
    Then the generated YAML contains a single "nginx" service block
    And the "nginx" block has Traefik labels for both "web" and "admin" exports
