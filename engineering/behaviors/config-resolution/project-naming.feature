# This feature verifies behaviors from:
# See: ../../specs/generated-override-files.md
# See: ../../specs/naming-conventions.md

Feature: Project Naming Hook
  As a developer using xcind
  I want Docker Compose project names set automatically
  So that container, volume, and network names don't collide across workspaces

  Scenario: Workspace mode project name
    Given an application "frontend" in workspace "dev"
    When xcind-naming-hook generates compose.naming.yaml
    Then the file contains:
      """
      name: dev-frontend
      """

  Scenario: Workspaceless mode project name
    Given an application "frontend" with no workspace
    When xcind-naming-hook generates compose.naming.yaml
    Then the file contains:
      """
      name: frontend
      """

  Scenario: Project name prevents collisions
    Given two workspaces "dev" and "review" both containing "frontend"
    When each workspace runs xcind-compose
    Then the Docker Compose project names are "dev-frontend" and "review-frontend"
    And their containers, volumes, and networks are isolated from each other
