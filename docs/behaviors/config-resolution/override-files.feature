# This feature verifies behaviors from:
# See: ../../specs/generated-override-files.md

Feature: Override File Resolution
  As a developer using xcind
  I want override files to be automatically discovered
  So that I can layer environment-specific configuration without manual file lists

  Background:
    Given an application with a .xcind.sh configuration

  # --- Override Derivation ---

  Scenario: Derive override for a YAML file with multiple dots
    Given a compose file named "compose.common.yaml"
    When xcind derives the override filename
    Then the override filename is "compose.common.override.yaml"

  Scenario: Derive override for a simple YAML file
    Given a compose file named "compose.yaml"
    When xcind derives the override filename
    Then the override filename is "compose.override.yaml"

  Scenario: Derive override preserving directory path
    Given a compose file named "docker/compose.dev.yaml"
    When xcind derives the override filename
    Then the override filename is "docker/compose.dev.override.yaml"

  Scenario: Derive override for a dotfile
    Given a file named ".env"
    When xcind derives the override filename
    Then the override filename is ".env.override"

  Scenario: Derive override for a dotfile with suffix
    Given a file named ".env.local"
    When xcind derives the override filename
    Then the override filename is ".env.local.override"

  Scenario: Derive override for an HCL file
    Given a file named "docker-bake.hcl"
    When xcind derives the override filename
    Then the override filename is "docker-bake.override.hcl"

  Scenario: Derive override for a shell file
    Given a file named ".xcind.dev.sh"
    When xcind derives the override filename
    Then the override filename is ".xcind.dev.override.sh"

  # --- Override Inclusion ---

  Scenario: Auto-include override file when it exists
    Given a compose file "compose.yaml" is listed in XCIND_COMPOSE_FILES
    And a file "compose.override.yaml" exists on disk
    When xcind resolves the compose file list
    Then "compose.override.yaml" is included after "compose.yaml"

  Scenario: Skip override file when it does not exist
    Given a compose file "compose.common.yaml" is listed in XCIND_COMPOSE_FILES
    And no file "compose.common.override.yaml" exists on disk
    When xcind resolves the compose file list
    Then "compose.common.override.yaml" is not included

  Scenario: Auto-derive overrides for environment-specific files
    Given a compose file "compose.dev.yaml" is listed in XCIND_COMPOSE_FILES
    And a file "compose.dev.override.yaml" exists on disk
    When xcind resolves the compose file list
    Then "compose.dev.override.yaml" is included after "compose.dev.yaml"
