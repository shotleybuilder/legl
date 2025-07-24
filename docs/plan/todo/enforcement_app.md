# EHS Enforcement App - Refactoring Plan

## Executive Summary

Extract the `legl_enforcement` functionality into a standalone Phoenix LiveView application called `ehs_enforcement` for collecting and publishing UK enforcement agency activity data to Airtable. The application will support multiple UK enforcement agencies including HSE (Health and Safety Executive), ONR (Office for Nuclear Regulation), ORR (Office of Rail and Road), EA (Environment Agency), and others. Built using the Ash framework for robust data modeling and API generation, it will be deployed on Digital Ocean using Docker.

## Current Architecture Analysis

### Module Structure
- **Core Modules**: 
  - `Legl.Countries.Uk.LeglEnforcement.Hse` - Common utilities
  - `Legl.Countries.Uk.LeglEnforcement.HseCases` - Court case processing
  - `Legl.Countries.Uk.LeglEnforcement.HseNotices` - Notice processing
  - `Legl.Countries.Uk.LeglEnforcement.HseBreaches` - Breach parsing and linking

### Dependencies
- **External Services**:
  - HSE website scraping (`Legl.Services.Hse.ClientCases/ClientNotices`)
  - Airtable API (`Legl.Services.Airtable.*`)
- **Internal Dependencies**:
  - `Legl.Countries.Uk.LeglRegister.TypeCode` - For legislation type classification
  - `Legl.Utility` - JSON saving functionality

## Proposed Architecture

### Application Structure (Ash Framework)
```
ehs_enforcement/
├── lib/
│   ├── ehs_enforcement/
│   │   ├── enforcement/           # Ash Domain - Core enforcement logic
│   │   │   ├── enforcement.ex    # Domain module
│   │   │   └── resources/        # Ash Resources
│   │   │       ├── case.ex
│   │   │       ├── notice.ex
│   │   │       ├── breach.ex
│   │   │       └── agency.ex
│   │   ├── agencies/             # Agency-specific implementations
│   │   │   ├── hse/              # Health and Safety Executive
│   │   │   │   ├── scraper.ex
│   │   │   │   └── parser.ex
│   │   │   ├── onr/              # Office for Nuclear Regulation
│   │   │   │   ├── scraper.ex
│   │   │   │   └── parser.ex
│   │   │   ├── orr/              # Office of Rail and Road
│   │   │   │   ├── scraper.ex
│   │   │   │   └── parser.ex
│   │   │   ├── ea/               # Environment Agency
│   │   │   │   ├── scraper.ex
│   │   │   │   └── parser.ex
│   │   │   └── common/           # Shared agency logic
│   │   │       └── base_scraper.ex
│   │   ├── integrations/         # Ash Domain - External integrations
│   │   │   ├── integrations.ex   # Domain module
│   │   │   └── resources/
│   │   │       └── airtable_sync.ex
│   │   ├── legislation/          # Ash Domain - Legislation reference
│   │   │   ├── legislation.ex    # Domain module
│   │   │   └── resources/
│   │   │       ├── act.ex
│   │   │       └── regulation.ex
│   │   ├── registry.ex          # Ash Registry
│   │   └── repo.ex              # Ecto Repo (if using local DB)
│   ├── ehs_enforcement_web/
│   │   ├── live/
│   │   │   ├── dashboard_live.ex
│   │   │   ├── enforcement/
│   │   │   │   ├── case_live/
│   │   │   │   │   ├── index.ex
│   │   │   │   │   ├── show.ex
│   │   │   │   │   └── form_component.ex
│   │   │   │   └── notice_live/
│   │   │   │       ├── index.ex
│   │   │   │       ├── show.ex
│   │   │   │       └── form_component.ex
│   │   │   ├── agency_live/     # Agency-specific views
│   │   │   │   ├── index.ex
│   │   │   │   └── show.ex
│   │   │   └── sync_live/
│   │   │       ├── index.ex
│   │   │       └── components/
│   │   │           └── sync_status.ex
│   │   └── components/
│   └── ehs_enforcement.ex
├── config/
├── priv/
│   └── resource_snapshots/       # Ash migrations
├── test/
├── Dockerfile
├── docker-compose.yml
└── mix.exs
```

### Key Features for LiveView App
1. **Dashboard** - Overview of enforcement activity
2. **Case Management** - Browse, search, and sync court cases
3. **Notice Management** - Browse, search, and sync enforcement notices
4. **Sync Control** - Manual and scheduled synchronization
5. **Breach Linking** - UI for verifying legislation links
6. **Export/Import** - Bulk operations support

## Git Workflow Recommendations

### 1. Repository Structure
```bash
# Create new repository in the designated location
mkdir -p ~/Desktop/ehs_enforcement
cd ~/Desktop/ehs_enforcement
git init

# Add main branch protection
git checkout -b main
```

### 2. Branch Strategy
- `main` - Production-ready code
- `develop` - Integration branch
- `feature/*` - New features
- `fix/*` - Bug fixes
- `refactor/*` - Code improvements

### 3. Migration Steps

#### Phase 1: Extract and Preserve History
```bash
# In the original repo
cd /home/jason/Desktop/legl/legl

# Create extraction branch
git checkout -b extract/ehs-enforcement

# Clone the repo to a temporary location for extraction
cd /tmp
git clone /home/jason/Desktop/legl/legl legl-extraction
cd legl-extraction

# Use git filter-repo to extract relevant files with history
pip install git-filter-repo
git filter-repo --path lib/legl/countries/uk/legl_enforcement/ \
                --path lib/legl/services/hse/ \
                --path lib/legl/services/airtable/ \
                --path test/legl/countries/uk/legl_enforcement/ \
                --path-rename lib/legl/:lib/ehs_enforcement/ \
                --path-rename test/legl/:test/ehs_enforcement/
```

#### Phase 2: Create New Phoenix App with Ash
```bash
# Create new Phoenix LiveView app in the designated location
cd ~/Desktop
mix phx.new ehs_enforcement --live
cd ehs_enforcement

# Add Ash and database dependencies to mix.exs
# deps:
#   {:ash, "~> 2.0"},
#   {:ash_phoenix, "~> 1.0"},
#   {:ash_postgres, "~> 1.0"},
#   {:ash_graphql, "~> 0.25"},
#   {:ash_json_api, "~> 0.32"},
#   {:ash_admin, "~> 0.9"},
#   {:supabase, "~> 0.3.0"}  # For future Supabase integration

# Install dependencies
mix deps.get

# Setup database
mix ecto.create

# Initialize git
git init
git add .
git commit -m "Initial Phoenix LiveView application with Ash framework and Ecto"

# Add extracted code
git remote add extraction /tmp/legl-extraction
git fetch extraction
git merge extraction/main --allow-unrelated-histories
```

#### Phase 3: Refactor Structure
```bash
# Create feature branch for refactoring
git checkout -b refactor/standalone-app

# Move and rename files to new structure
mkdir -p lib/ehs_enforcement/{enforcement,scrapers,integrations,legislation}

# Update module names and dependencies
# Commit changes incrementally
git add -p
git commit -m "refactor: reorganize module structure"
```

#### Phase 4: Remove Code from Original Repository
```bash
# In the original legl repo
cd /home/jason/Desktop/legl/legl

# Create a new branch for removal
git checkout -b remove/ehs-enforcement

# Remove the extracted modules
rm -rf lib/legl/countries/uk/legl_enforcement/
rm -rf lib/legl/services/hse/
rm -rf test/legl/countries/uk/legl_enforcement/

# Update any references in remaining code
# Commit the removal
git add -A
git commit -m "refactor: extract EHS enforcement to separate application"

# Create PR for review before merging to main
```

### 4. Continuous Integration
```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.14'
          otp-version: '25'
      - run: mix deps.get
      - run: mix test
      - run: mix format --check-formatted
      - run: mix credo
```

## Implementation Plan

### Phase 1: Foundation (Week 1-2)
1. Extract code with git history
2. Create new Phoenix LiveView app
3. Set up CI/CD pipeline
4. Migrate core enforcement modules
5. Create basic LiveView dashboard

### Phase 2: Service Integration (Week 3-4)
1. Refactor Airtable client for standalone use
2. Setup PostgreSQL database schema
3. Implement Airtable-to-PostgreSQL sync
4. Refactor HSE scraper modules
5. Add configuration management
6. Implement error handling and logging

### Phase 3: LiveView UI (Week 5-6)
1. Create case management interface
2. Create notice management interface
3. Add search and filter capabilities
4. Implement sync status monitoring

### Phase 4: Multi-Agency Support (Week 7-8)
1. Implement ONR agency scraper
2. Implement ORR agency scraper
3. Implement EA agency scraper
4. Create agency configuration UI
5. Add agency-specific dashboards

### Phase 5: Advanced Features (Week 9-10)
1. Add breach verification UI
2. Implement bulk operations
3. Add export/import functionality
4. Create admin settings page
5. Implement Ash policies for authorization

### Phase 6: API and Integration (Week 11)
1. Configure GraphQL API
2. Configure JSON:API
3. Add API documentation
4. Implement webhook notifications

### Phase 7: Production Ready (Week 12)
1. Add authentication (if needed)
2. Implement rate limiting
3. Add monitoring and alerting
4. Complete documentation
5. Deploy to production

## Database Strategy

### Phase 1: Airtable Primary (Current)
- All records created in Airtable
- Minimal changes to existing workflow
- Direct integration maintained
- Limited querying capabilities

### Phase 2: Hybrid Approach (Future)
- PostgreSQL/Supabase for read operations
- Airtable remains the source of truth
- Sync data from Airtable to local DB
- Better performance for searches and filtering
- Enable complex queries and reporting

### Phase 3: Full Migration (Long-term)
- PostgreSQL/Supabase as primary database
- Create, read, update operations in local DB
- Optional sync to Airtable for legacy systems
- Full control over data schema
- Better scalability and performance

**Implementation Strategy**:
1. Start with Ecto/PostgreSQL setup from day one
2. Initially use Airtable for all operations
3. Gradually implement local caching
4. Eventually migrate to full CRUD in PostgreSQL/Supabase

## Configuration Management

### Environment Variables
```elixir
# config/runtime.exs
config :ehs_enforcement,
  airtable_api_key: System.get_env("AIRTABLE_API_KEY"),
  airtable_base_id: System.get_env("AIRTABLE_BASE_ID"),
  sync_interval: String.to_integer(System.get_env("SYNC_INTERVAL", "3600")),
  agencies: [
    hse: [
      name: "Health and Safety Executive",
      base_url: System.get_env("HSE_BASE_URL", "https://resources.hse.gov.uk")
    ],
    onr: [
      name: "Office for Nuclear Regulation",
      base_url: System.get_env("ONR_BASE_URL", "https://www.onr.org.uk")
    ],
    orr: [
      name: "Office of Rail and Road",
      base_url: System.get_env("ORR_BASE_URL", "https://www.orr.gov.uk")
    ],
    ea: [
      name: "Environment Agency",
      base_url: System.get_env("EA_BASE_URL", "https://www.gov.uk/government/organisations/environment-agency")
    ]
  ]
```

### Docker Configuration
```dockerfile
# Dockerfile
# Build stage
FROM elixir:1.14-alpine AS build

RUN apk add --no-cache build-base git

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./
COPY config config

# Install dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy source code
COPY lib lib
COPY priv priv

# Compile assets
COPY assets assets
RUN mix assets.deploy

# Build release
RUN mix release

# Runtime stage
FROM alpine:3.18 AS runtime

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

# Copy release from build stage
COPY --from=build /app/_build/prod/rel/ehs_enforcement ./

# Set environment
ENV HOME=/app
ENV PORT=4000

EXPOSE 4000

CMD ["bin/ehs_enforcement", "start"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "4000:4000"
    environment:
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - DATABASE_URL=${DATABASE_URL}  # PostgreSQL connection string
      - AIRTABLE_API_KEY=${AIRTABLE_API_KEY}
      - AIRTABLE_BASE_ID=${AIRTABLE_BASE_ID}
      - HSE_BASE_URL=https://resources.hse.gov.uk
      - PHX_HOST=${PHX_HOST}
      - PORT=4000
      - SUPABASE_URL=${SUPABASE_URL}  # For future Supabase integration
      - SUPABASE_KEY=${SUPABASE_KEY}  # For future Supabase integration
    restart: unless-stopped
    depends_on:
      - db

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=ehs_enforcement
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=ehs_enforcement_prod
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  postgres_data:
```

## Testing Strategy

1. **Unit Tests** - Core logic and parsers
2. **Integration Tests** - Airtable and HSE clients
3. **LiveView Tests** - UI interactions
4. **End-to-End Tests** - Full sync workflows

## Deployment Strategy - Digital Ocean

### Digital Ocean Setup
```bash
# Create a Digital Ocean Droplet
# Recommended: Ubuntu 22.04 LTS, 2GB RAM minimum

# SSH into the droplet
ssh root@your-droplet-ip

# Install Docker and Docker Compose
apt update
apt install -y docker.io docker-compose
systemctl enable docker
systemctl start docker

# Create deployment directory
mkdir -p /opt/ehs_enforcement
cd /opt/ehs_enforcement

# Clone the repository
git clone https://github.com/your-org/ehs_enforcement.git .

# Create environment file
cat > .env << EOF
SECRET_KEY_BASE=your-secret-key-base
AIRTABLE_API_KEY=your-airtable-api-key
AIRTABLE_BASE_ID=your-airtable-base-id
PHX_HOST=your-domain.com
EOF

# Build and run
docker-compose up -d

# Setup Nginx reverse proxy (optional)
apt install -y nginx
```

### Nginx Configuration
```nginx
# /etc/nginx/sites-available/ehs_enforcement
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### GitHub Actions for CI/CD
```yaml
# .github/workflows/deploy.yml
name: Deploy to Digital Ocean

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to Digital Ocean
        uses: appleboy/ssh-action@v0.1.5
        with:
          host: ${{ secrets.DO_HOST }}
          username: root
          key: ${{ secrets.DO_SSH_KEY }}
          script: |
            cd /opt/ehs_enforcement
            git pull origin main
            docker-compose build
            docker-compose up -d
```

## Risk Mitigation

1. **Data Loss**: Maintain backups during migration
2. **API Changes**: Abstract scraping logic
3. **Rate Limits**: Implement throttling
4. **Downtime**: Use blue-green deployment

## Ash Framework Implementation Details

### Example Ash Resource
```elixir
# lib/ehs_enforcement/enforcement/resources/case.ex
defmodule EhsEnforcement.Enforcement.Case do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :agency_id, :uuid, allow_nil?: false
    attribute :case_number, :string, allow_nil?: false
    attribute :offender_name, :string
    attribute :offence_date, :date
    attribute :fine_amount, :decimal
    attribute :status, :atom, constraints: [one_of: [:open, :closed, :appealed]]
    timestamps()
  end

  relationships do
    belongs_to :agency, EhsEnforcement.Enforcement.Agency
    has_many :breaches, EhsEnforcement.Enforcement.Breach
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    action :sync_from_agency, :map do
      argument :agency_code, :atom, allow_nil?: false
      run EhsEnforcement.Enforcement.Actions.SyncFromAgency
    end
  end
end
```

### Agency Configuration
```elixir
# lib/ehs_enforcement/agencies/common/agency_behaviour.ex
defmodule EhsEnforcement.Agencies.AgencyBehaviour do
  @callback fetch_cases(opts :: keyword()) :: {:ok, list(map())} | {:error, term()}
  @callback fetch_notices(opts :: keyword()) :: {:ok, list(map())} | {:error, term()}
  @callback parse_case(html :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback parse_notice(html :: String.t()) :: {:ok, map()} | {:error, term()}
end
```

## Success Metrics

- Zero data loss during migration
- Support for 4+ UK enforcement agencies
- Improved performance (target: 2x faster syncs)
- Reduced maintenance overhead
- Clear separation of concerns
- API availability for third-party integrations
- Extensible architecture for adding new agencies

## Next Steps

1. Review and approve this plan
2. Set up new repository
3. Begin Phase 1 extraction
4. Schedule weekly progress reviews
5. Plan stakeholder communications