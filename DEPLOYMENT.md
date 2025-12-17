# Posduif Deployment Guide

This guide covers deploying Posduif to production environments.

## Prerequisites

- Docker and Docker Compose (for containerized deployment)
- Terraform >= 1.0 (for infrastructure provisioning)
- Ansible >= 2.9 (for configuration management)
- AWS CLI configured (for cloud deployment)
- SSH access to target servers

## Deployment Methods

### 1. Docker Compose Deployment (Recommended for Single Server)

This method deploys all services using Docker Compose on a single server.

#### Steps

1. **Build the sync engine image:**
   ```bash
   cd sync-engine
   docker build -t posduif/sync-engine:latest .
   ```

2. **Configure environment variables:**
   ```bash
   cp .env.example .env.prod
   # Edit .env.prod with production values
   ```

3. **Deploy:**
   ```bash
   ./scripts/deploy.sh -e prod -m docker
   ```

#### Manual Docker Compose Deployment

```bash
cd infrastructure
docker-compose -f docker-compose.prod.yml up -d
```

### 2. Ansible Deployment (Recommended for Multiple Servers)

Ansible automates deployment across multiple servers with configuration management.

#### Setup

1. **Create inventory file:**
   ```bash
   cp infrastructure/ansible/inventory/production.yml infrastructure/ansible/inventory/my-prod.yml
   # Edit with your server details
   ```

2. **Configure variables:**
   - Edit `infrastructure/ansible/inventory/my-prod.yml`
   - Set database, Redis, and JWT secret values

3. **Deploy:**
   ```bash
   ./scripts/deploy.sh -e prod -m ansible
   ```

#### Manual Ansible Deployment

```bash
cd infrastructure/ansible
ansible-playbook -i inventory/production.yml playbooks/production.yml
```

### 3. Terraform Infrastructure Deployment (Cloud)

Terraform provisions AWS infrastructure (VPC, RDS, ElastiCache, EC2).

#### Setup

1. **Configure AWS credentials:**
   ```bash
   aws configure
   ```

2. **Create terraform.tfvars:**
   ```hcl
   aws_region = "us-east-1"
   db_username = "posduif"
   db_password = "your-secure-password"
   ami_id = "ami-xxxxxxxxx"
   key_name = "your-key-pair"
   instance_type = "t3.small"
   environment = "prod"
   ```

3. **Deploy infrastructure:**
   ```bash
   ./scripts/deploy.sh -e prod -m terraform
   ```

#### Manual Terraform Deployment

```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

## Environment Configuration

### Environment Variables

Create `.env.prod` file with the following variables:

```bash
# Database
POSTGRES_HOST=your-db-host
POSTGRES_PORT=5432
POSTGRES_USER=posduif
POSTGRES_PASSWORD=your-secure-password
POSTGRES_DB=tenant_1

# Redis
REDIS_HOST=your-redis-host
REDIS_PORT=6379
REDIS_PASSWORD=your-redis-password

# Sync Engine
SSE_PORT=8080
JWT_SECRET=your-jwt-secret-key

# Logging
LOG_LEVEL=info
```

### Configuration File

Edit `config/config.yaml` for production:

```yaml
postgres:
  host: ${POSTGRES_HOST}
  port: 5432
  user: ${POSTGRES_USER}
  password: ${POSTGRES_PASSWORD}
  db: ${POSTGRES_DB}
  max_connections: 50
  ssl_mode: require

redis:
  host: ${REDIS_HOST}
  port: 6379
  password: ${REDIS_PASSWORD}
  streams:
    enabled: true

sse:
  port: 8080
  read_timeout: 60s
  write_timeout: 30s

auth:
  jwt_secret: ${JWT_SECRET}
  jwt_expiration: 3600

logging:
  level: info
  format: json
```

## Health Checks

### Manual Health Check

```bash
./scripts/health-check.sh
```

### Automated Health Checks

The sync engine includes a health endpoint:

```bash
curl http://localhost:8080/health
```

Expected response: `OK`

### Service Health Checks

- **Sync Engine**: `GET /health`
- **PostgreSQL**: Connection test
- **Redis**: `PING` command

## Monitoring

### Logs

View sync engine logs:

```bash
docker logs posduif-sync-engine
# or
journalctl -u posduif-sync-engine -f
```

### Metrics

Monitor the following:

- API response times
- Database connection pool usage
- Redis memory usage
- SSE connection count
- Error rates

## Backup and Recovery

### Database Backup

```bash
# PostgreSQL backup
pg_dump -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB > backup.sql

# Restore
psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB < backup.sql
```

### Redis Backup

Redis persistence is configured via AOF (Append Only File). Snapshots are saved automatically.

## Scaling

### Horizontal Scaling

1. Deploy multiple sync engine instances behind a load balancer
2. Use shared PostgreSQL and Redis instances
3. Configure sticky sessions for SSE connections

### Vertical Scaling

1. Increase EC2 instance size
2. Increase RDS instance class
3. Increase Redis node size

## Security

### SSL/TLS

Configure reverse proxy (nginx/traefik) with SSL certificates:

```nginx
server {
    listen 443 ssl;
    server_name posduif.example.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Firewall Rules

- Allow only necessary ports (80, 443, 22)
- Restrict database access to internal network
- Use security groups in AWS

### Secrets Management

- Use AWS Secrets Manager or HashiCorp Vault
- Never commit secrets to version control
- Rotate JWT secrets regularly

## Troubleshooting

### Service Won't Start

1. Check logs: `docker logs posduif-sync-engine`
2. Verify environment variables
3. Check database connectivity
4. Verify Redis connectivity

### High Memory Usage

1. Check connection pool settings
2. Review SSE connection count
3. Monitor Redis memory usage
4. Consider scaling horizontally

### Database Connection Issues

1. Verify network connectivity
2. Check security group rules
3. Verify credentials
4. Check connection pool limits

## Rollback

### Docker Compose Rollback

```bash
cd infrastructure
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d -f previous-version
```

### Ansible Rollback

```bash
cd infrastructure/ansible
ansible-playbook -i inventory/production.yml playbooks/rollback.yml
```

## Support

For issues or questions:

1. Check logs first
2. Review health check status
3. Consult troubleshooting section
4. Open an issue on GitHub

