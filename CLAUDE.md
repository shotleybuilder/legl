# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

```bash
# Install dependencies
mix deps.get

# Compile the project
mix compile

# Run tests
mix test

# Run a specific test file
mix test test/path/to/test_file.exs

# Format code
mix format

# Generate documentation
mix docs

# Run the application
mix run

# Code quality check
mix credo
```

## Architecture Overview

This is an Elixir application using Phoenix framework (v1.6) that parses European and Middle Eastern environmental, health and safety legislation. The system transforms legislation text (HTML/PDF) into standardized annotated text files, then converts them to Airtable-compatible format.

### Core Architecture Pattern

The application follows a modular, country-based architecture where each country has its own parser module:

```
lib/legl/
├── countries/           # Country-specific parsers (uk/, de/, dk/, etc.)
│   └── uk/             # Most developed implementation
│       ├── legl_article/      # Article parsing
│       ├── legl_fitness/      # Fitness and rule processing
│       ├── legl_register/     # Legal register management
│       └── legl_enforcement/  # HSE enforcement data
├── services/           # External service integrations
│   ├── airtable/      # Airtable API client
│   ├── supabase/      # Supabase database client
│   └── legislation_gov_uk/  # UK legislation website client
└── data_files/        # Static data (CSV, HTML, JSON, TXT)
```

### Data Processing Pipeline

1. **Parse**: Extract text from legislation websites (HTML) or documents (PDF)
2. **Annotate**: Create standardized annotated text files for quality control
3. **Transform**: Convert to Airtable-compatible format with proper field mapping
4. **Store**: Save to Airtable or Supabase databases

### Key Integration Points

- **Airtable**: Primary data storage using Tesla HTTP client
- **Supabase**: Alternative database backend
- **legislation.gov.uk**: Source for UK legislation text
- **HSE**: Health & Safety Executive enforcement data

### Testing Approach

- Uses ExUnit with Mox for mocking external services
- Test files mirror the lib directory structure
- Run specific tests with: `mix test test/legl/countries/uk/specific_test.exs`

### Important Patterns

1. **Parser Modules**: Each country implements its own parser following a common interface
2. **Service Isolation**: External API calls are wrapped in service modules
3. **Configuration**: Environment-specific settings in `config/` directory
4. **Type Safety**: Type definitions in `lib/legl/types/` for Airtable schemas