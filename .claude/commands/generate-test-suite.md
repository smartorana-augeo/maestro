# Create Test Suite

Create a comprehensive test suite plan for a specific area or feature.

## Usage
When invoked, you'll be prompted for:
- AREA_NAME: The area or feature to test (e.g., "user authentication", "payment processing")
- TEST_TYPE: Optional - specific test type (unit, integration, e2e, performance, or "all")

## Instructions

Create a comprehensive test suite for the specified area.

### Context Locations
- **Code**: Look in the `repositories/` folder for the relevant repository
- **Existing Tests**: Review existing test files and patterns
- **Documentation**: Check `docs/tech/` for testing standards

### Test Strategy Overview
- Testing approach and methodology
- Test coverage goals and metrics
- Testing tools and frameworks to use
- Test data management strategy

### Test Categories

#### Unit Tests
- Individual component testing
- Function and method testing
- Mock and stub strategies
- Test isolation and independence
- Edge cases and boundary conditions

#### Integration Tests
- Component interaction testing
- API integration testing
- Database integration testing
- External service integration
- Data flow validation

#### End-to-End Tests
- User journey testing
- Complete workflow validation
- Cross-browser and cross-platform testing
- Performance under load
- Error handling and recovery

#### Performance Tests
- Load testing scenarios
- Stress testing requirements
- Performance benchmarks
- Resource utilization monitoring
- Scalability testing

### Test Implementation Plan
- Test file organization and structure
- Test data setup and teardown
- Test environment configuration
- CI/CD integration requirements
- Test reporting and metrics

### Specific Test Cases
- Detailed test case descriptions
- Input data and expected outputs
- Test steps and validation criteria
- Error scenarios and negative testing
- Regression testing requirements

### Test Automation
- Automated test execution
- Test scheduling and triggers
- Test result reporting
- Failure analysis and debugging
- Test maintenance and updates

### Quality Assurance
- Code review for test code
- Test coverage analysis
- Test performance optimization
- Test reliability and stability
- Continuous improvement process

### Save as Project
Create a project file in `projects/public/` with naming convention:
`YYYY-MM-DD-{area-name}-test-suite.project.md`

Include YAML frontmatter:
```yaml
---
title: {AREA_NAME} Test Suite
description: Comprehensive test suite for {area name}
status: planning
priority: medium
owner: {your name}
created: {today}
tags: [testing, test-suite, {area-name}]
test_type: {TEST_TYPE}
---
```
