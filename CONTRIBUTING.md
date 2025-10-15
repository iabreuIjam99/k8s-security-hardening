# Contributing to K8s Security Hardening

First off, thank you for considering contributing to this project! 🎉

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues. When creating a bug report, include:

- **Clear title** and description
- **Steps to reproduce** the behavior
- **Expected behavior**
- **Actual behavior**
- **Environment details** (OS, Kubernetes version, etc.)
- **Logs** if applicable

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear title**
- **Provide detailed description**
- **Explain why** this enhancement would be useful
- **Provide examples** if possible

### Pull Requests

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Make your changes
4. Test thoroughly
5. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
6. Push to the branch (`git push origin feature/AmazingFeature`)
7. Open a Pull Request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/k8s-security-hardening.git
cd k8s-security-hardening

# Add upstream
git remote add upstream https://github.com/iabreuIjam99/k8s-security-hardening.git

# Install dependencies
make init
```

## Code Style

### Terraform
- Use `terraform fmt` before committing
- Follow [HashiCorp style guide](https://www.terraform.io/docs/language/syntax/style.html)
- Add comments for complex logic

### Shell Scripts
- Use shellcheck
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Add error handling

### YAML
- 2 spaces indentation
- Use yamllint

### Commit Messages
- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- First line max 72 characters
- Reference issues and pull requests

Example:
```
Add OPA policy for pod security

- Implement constraint template
- Add tests
- Update documentation

Fixes #123
```

## Testing

Before submitting a PR:

```bash
# Validate Terraform
cd terraform
terraform fmt -check -recursive
terraform validate

# Validate policies
cd ../scripts
./validate-policies.sh

# Run security tests
./security-tests.sh

# Lint shell scripts
shellcheck *.sh
```

## Documentation

- Update README.md if needed
- Add/update docs in `docs/` directory
- Include examples
- Update ROADMAP.md if adding features

## Community

- Be respectful
- Be welcoming
- Be considerate
- Follow [Code of Conduct](CODE_OF_CONDUCT.md)

## Recognition

Contributors will be:
- Listed in README.md
- Mentioned in release notes
- Given credit in documentation

## Questions?

Feel free to:
- Open an issue
- Start a discussion
- Reach out on social media

Thank you for contributing! 🙏
