# Security Policy

## Overview

Delwaqty takes security seriously. This document outlines our security practices and how to report vulnerabilities.

## Authentication

- Supabase Auth with JWT tokens
- Role-based access control (RBAC)
- Session management with automatic expiry
- Secure token storage

## Data Protection

- All API calls use HTTPS
- Sensitive data encrypted at rest
- Environment variables for secrets (never committed)
- RLS policies on all Supabase tables

## API Security

- Rate limiting on all endpoints
- Input validation and sanitization
- CORS configured per environment
- API key rotation policy

## Mobile Security

- App Check enabled in production
- Certificate pinning for API calls
- Obfuscation enabled for release builds
- No hardcoded secrets in binary

## Reporting Vulnerabilities

If you discover a security vulnerability, please report it responsibly:
1. Do NOT open a public GitHub issue
2. Email: security@delwaqty.com (when available)
3. Include detailed reproduction steps

## Security Checklist

- [ ] Environment variables configured
- [ ] RLS policies enabled on all tables
- [ ] API keys rotated periodically
- [ ] Dependencies updated regularly
- [ ] Code signed for release builds
