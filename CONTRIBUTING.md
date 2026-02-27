# Contributing to Robot Tank Control

First off, thank you for considering contributing to Robot Tank Control! It's people like you that make this project such a great tool for the community.

## Table of Contents

- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Your First Code Contribution](#your-first-code-contribution)
  - [Pull Requests](#pull-requests)
- [Styleguides](#styleguides)
  - [Ruby Styleguide](#ruby-styleguide)
  - [JavaScript Styleguide](#javascript-styleguide)
  - [CSS Styleguide](#css-styleguide)
- [Testing](#testing)

## How Can I Contribute?

### Reporting Bugs

This section guides you through submitting a bug report for Robot Tank Control. Following these guidelines helps maintainers and the community understand your report, reproduce the behavior, and find related reports.

Before creating bug reports, please check the [Issue Tracker](https://github.com/matiyas/robot/issues) as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible and use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md).

### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion for Robot Tank Control, including completely new features and minor improvements to existing functionality. Following these guidelines helps maintainers and the community understand your suggestion and find related suggestions.

When you are creating an enhancement suggestion, please include as many details as possible and use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md).

### Your First Code Contribution

Unsure where to begin contributing? You can start by looking through these `beginner` and `help-wanted` issues:

- Beginner issues - issues which should only require a few lines of code, and a test or two.
- Help wanted issues - issues which should be a bit more involved than beginner issues.

### Pull Requests

The process which should be followed to get a pull request (PR) merged:

1.  Fork the repo and create your branch from `main`.
2.  If you've added code that should be tested, add tests.
3.  If you've changed APIs, update the documentation.
4.  Ensure the test suite passes.
5.  Make sure your code lints.
6.  Issue that pull request!

## Styleguides

### Ruby Styleguide

All Ruby code should follow the [Ruby Style Guide](https://github.com/rubocop/ruby-style-guide). We use RuboCop to enforce these rules.

```bash
# Run RuboCop
bundle exec rubocop
```

### JavaScript Styleguide

JavaScript should follow the standard project style. Avoid using external libraries if possible to keep the project lightweight.

### CSS Styleguide

CSS should be clean and responsive. We prefer vanilla CSS without preprocessors unless absolutely necessary.

## Testing

Before submitting a pull request, ensure all tests pass:

```bash
# Run all tests
bundle exec rspec
```

If you're using Docker:

```bash
# Run tests in Docker
make test
```

## Additional Notes

- **Commit Messages**: We follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).
- **License**: By contributing, you agree that your contributions will be licensed under its [MIT License](LICENSE).
