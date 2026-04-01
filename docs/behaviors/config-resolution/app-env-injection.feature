# This feature verifies behaviors from:
# See: ../../specs/generated-override-files.md
# See: ../../specs/configuration-schemas.md

Feature: App Environment File Injection
  As a developer using xcind
  I want environment files injected into my containers automatically
  So that I don't need to manually add env_file directives to my compose files

  Scenario: Injecting env files into all services
    Given an application with XCIND_APP_ENV_FILES=(".env" ".env.local")
    And the application has services "web" and "worker"
    And both ".env" and ".env.local" exist on disk
    When xcind-app-env-hook generates compose.app-env.yaml
    Then each service has an env_file list containing absolute paths to both files

  Scenario: Only existing files are included
    Given an application with XCIND_APP_ENV_FILES=(".env" ".env.local")
    And only ".env" exists on disk
    When xcind-app-env-hook generates compose.app-env.yaml
    Then each service has an env_file list containing only the path to ".env"

  Scenario: No app env files configured
    Given an application with XCIND_APP_ENV_FILES=()
    When the hook pipeline runs
    Then no compose.app-env.yaml is generated

  Scenario: Env files use absolute paths
    Given an application at "/Users/dev/myapp" with XCIND_APP_ENV_FILES=(".env")
    And ".env" exists on disk
    When xcind-app-env-hook generates compose.app-env.yaml
    Then the env_file path is "/Users/dev/myapp/.env" (absolute, not relative)
