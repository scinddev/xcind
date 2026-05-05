# This feature verifies behaviors from:
# See: ../../specs/configuration-schemas.md

Feature: Variable Expansion in File Patterns
  As a developer using xcind
  I want shell variables in file patterns to be expanded
  So that I can use environment-driven compose file selection

  Background:
    Given an application with a .xcind.sh configuration

  Scenario: Expand ${APP_ENV} in compose file pattern
    Given XCIND_COMPOSE_FILES includes "compose.${APP_ENV}.yaml"
    And the environment variable APP_ENV is set to "dev"
    And a file "compose.dev.yaml" exists on disk
    When xcind resolves the compose file list
    Then "compose.dev.yaml" is included in the resolved files

  Scenario: Derive override for an expanded file pattern
    Given XCIND_COMPOSE_FILES includes "compose.${APP_ENV}.yaml"
    And the environment variable APP_ENV is set to "dev"
    And a file "compose.dev.yaml" exists on disk
    And a file "compose.dev.override.yaml" exists on disk
    When xcind resolves the compose file list
    Then "compose.dev.override.yaml" is included after "compose.dev.yaml"

  Scenario: Skip expanded pattern when resolved file does not exist
    Given XCIND_COMPOSE_FILES includes "compose.${APP_ENV}.yaml"
    And the environment variable APP_ENV is set to "prod"
    And no file "compose.prod.yaml" exists on disk
    When xcind resolves the compose file list
    Then "compose.prod.yaml" is not included in the resolved files
