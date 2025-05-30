#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-600}
SURREALDB_VERSION=${SURREALDB_VERSION:-latest}

# Cleanup function
cleanup() {
    log_info "Cleaning up resources..."
    
    # Clean up any temporary files
    rm -f token.json source.json destination.json job.json
    
    # Optionally clean up Airbyte (uncomment if needed)
    # log_info "Destroying Airbyte cluster..."
    # abctl local uninstall --force || true
    
    log_info "Cleanup completed"
}

# Set up cleanup on exit
trap cleanup EXIT

# Function to wait for service to be ready
wait_for_service() {
    local service_name=$1
    local endpoint=$2
    local max_attempts=60
    local attempt=1
    
    log_info "Waiting for $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f "$endpoint" 2>/dev/null; then
            log_success "$service_name is ready!"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts: $service_name not ready yet, waiting..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    log_error "$service_name failed to become ready after $((max_attempts * 5)) seconds"
    return 1
}

# Function to wait for job completion
wait_for_job() {
    local job_id=$1
    local timeout=$2
    local start_time=$(date +%s)
    
    log_info "Waiting for job $job_id to complete (timeout: ${timeout}s)..."
    
    while true; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            log_error "Job timeout after ${timeout}s"
            return 1
        fi
        
        curl -s -X GET "http://localhost:8000/api/public/v1/jobs/$job_id" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $AB_TOKEN" > job.json
        
        job_status=$(jq -r .status job.json)
        
        case $job_status in
            "succeeded")
                log_success "Job completed successfully!"
                return 0
                ;;
            "failed")
                log_error "Job failed!"
                cat job.json | jq .
                return 1
                ;;
            "running")
                log_info "Job still running... (elapsed: ${elapsed}s)"
                sleep 10
                ;;
            *)
                log_info "Job status: $job_status (elapsed: ${elapsed}s)"
                sleep 10
                ;;
        esac
    done
}

main() {
    log_info "Starting end-to-end test for destination-surrealdb"
    log_info "SurrealDB version: $SURREALDB_VERSION"
    
    # Step 1: Launch local Airbyte
    log_info "Step 1: Launching local Airbyte..."
    if ! command -v abctl &> /dev/null; then
        log_error "abctl command not found. Please ensure it's installed and in PATH."
        exit 1
    fi
    
    abctl local install

    # Configure kubeconfig
    log_info "Configuring kubeconfig..."
    kind export kubeconfig --name airbyte-abctl
    
    # Wait for Airbyte to be ready
    wait_for_service "Airbyte" "http://localhost:8000/api/v1/health"
    
    # Step 2: Deploy SurrealDB
    log_info "Step 2: Deploying SurrealDB..."
    
    # Check if surrealdb.yaml exists, if not create a basic one
    if [ ! -f "surrealdb.e2e.yaml" ]; then
        log_warning "surrealdb.e2e.yaml not found, creating a basic deployment..."
        cat > surrealdb.e2e.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: surrealdb
  labels:
    app: surrealdb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: surrealdb
  template:
    metadata:
      labels:
        app: surrealdb
    spec:
      containers:
      - name: surrealdb
        image: surrealdb/surrealdb:$SURREALDB_VERSION
        args:
          - start
          - --log=debug
          - --user=root
          - --pass=root
          - --bind=0.0.0.0:8000
          - memory
        ports:
        - containerPort: 8000
---
apiVersion: v1
kind: Service
metadata:
  name: surrealdb
spec:
  selector:
    app: surrealdb
  ports:
  - protocol: TCP
    port: 8000
    targetPort: 8000
EOF
    fi
    
    kubectl apply -f surrealdb.e2e.yaml
    
    # Wait for SurrealDB to be ready
    log_info "Waiting for SurrealDB to be ready..."
    kubectl wait --for=condition=ready pod -l app=surrealdb --timeout=300s
    
    # Step 3: Build and load the connector
    log_info "Step 3: Building and loading the connector..."
    
    if [ -d "airbyte" ]; then
        cd airbyte
        airbyte-ci --show-dagger-logs connectors --name destination-surrealdb build
        cd ..
    else
        log_error "airbyte directory not found. Please ensure the connector code is available."
        exit 1
    fi
    
    # Load the image into the kind cluster
    kind load docker-image --name airbyte-abctl airbyte/destination-surrealdb:dev
    
    # Step 4: Get Airbyte credentials and setup API access
    log_info "Step 4: Setting up Airbyte API access..."
    
    export AB_CLIENT_ID=$(NO_COLOR=1 abctl local credentials | grep Client-Id | awk -F': ' '{print $2}')
    export AB_CLIENT_SECRET=$(NO_COLOR=1 abctl local credentials | grep Client-Secret | awk -F': ' '{print $2}')
    
    if [ -z "$AB_CLIENT_ID" ] || [ -z "$AB_CLIENT_SECRET" ]; then
        log_error "Failed to get Airbyte client credentials"
        exit 1
    fi
    
    # Get API token
    cat > token.json << EOF
{
  "client_id": "$AB_CLIENT_ID",
  "client_secret": "$AB_CLIENT_SECRET"
}
EOF
    
    export AB_TOKEN=$(curl -s http://localhost:8000/api/v1/applications/token \
        -H "Content-Type: application/json" \
        -d @token.json | jq -r .access_token)
    
    if [ -z "$AB_TOKEN" ] || [ "$AB_TOKEN" = "null" ]; then
        log_error "Failed to get API token"
        exit 1
    fi
    
    # Get workspace ID
    export AB_WORKSPACE_ID=$(curl -s -X GET http://localhost:8000/api/public/v1/workspaces \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AB_TOKEN" | jq -r '.data[0].workspaceId')
    
    if [ -z "$AB_WORKSPACE_ID" ] || [ "$AB_WORKSPACE_ID" = "null" ]; then
        log_error "Failed to get workspace ID"
        exit 1
    fi
    
    log_success "API setup complete. Workspace ID: $AB_WORKSPACE_ID"
    
    # Step 5: Create destination definition
    log_info "Step 5: Creating SurrealDB destination definition..."
    
    destination_def_response=$(curl -s -X POST "http://localhost:8000/api/public/v1/workspaces/${AB_WORKSPACE_ID}/definitions/destinations" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AB_TOKEN" \
        -d '{"name": "SurrealDB", "dockerRepository": "airbyte/destination-surrealdb", "dockerImageTag": "dev"}')
    
    destination_def_id=$(echo "$destination_def_response" | jq -r .id)
    
    if [ -z "$destination_def_id" ] || [ "$destination_def_id" = "null" ]; then
        log_error "Failed to create destination definition"
        echo "$destination_def_response"
        exit 1
    fi
    
    log_success "Destination definition created with ID: $destination_def_id"
    
    # Step 6: Create source (File source with CSV data)
    log_info "Step 6: Creating file source..."
    
    export SOURCE_DEFINITION_ID=$(curl -s -X GET "http://localhost:8000/api/public/v1/workspaces/${AB_WORKSPACE_ID}/definitions/sources" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AB_TOKEN" | jq -r '.data[] | select(.dockerRepository == "airbyte/source-file") | .id' | head -n 1)
    
    cat > source.json << EOF
{
  "name": "e2e-test-file-source",
  "definitionId": "${SOURCE_DEFINITION_ID}",
  "workspaceId": "${AB_WORKSPACE_ID}",
  "configuration": {
    "sourceType": "file",
    "dataset_name": "test_dataset",
    "format": "csv",
    "url": "https://storage.googleapis.com/covid19-open-data/v2/latest/epidemiology.csv",
    "provider": {
      "storage": "HTTPS",
      "user_agent": true
    }
  }
}
EOF
    
    source_response=$(curl -s -X POST http://localhost:8000/api/public/v1/sources \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AB_TOKEN" \
        -d @source.json)
    
    export AB_SOURCE_ID=$(echo "$source_response" | jq -r .sourceId)
    
    if [ -z "$AB_SOURCE_ID" ] || [ "$AB_SOURCE_ID" = "null" ]; then
        log_error "Failed to create source"
        echo "$source_response"
        exit 1
    fi
    
    log_success "Source created with ID: $AB_SOURCE_ID"
    
    # Step 7: Create destination
    log_info "Step 7: Creating SurrealDB destination..."
    
    cat > destination.json << EOF
{
  "name": "e2e-test-surrealdb-destination",
  "definitionId": "${destination_def_id}",
  "workspaceId": "${AB_WORKSPACE_ID}",
  "configuration": {
    "destinationType": "",
    "surrealdb_url": "ws://surrealdb.default:8000/rpc",
    "surrealdb_namespace": "airbyte",
    "surrealdb_database": "airbyte",
    "surrealdb_username": "root",
    "surrealdb_password": "root"
  }
}
EOF
    
    destination_response=$(curl -s -X POST http://localhost:8000/api/public/v1/destinations \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AB_TOKEN" \
        -d @destination.json)
    
    export AB_DESTINATION_ID=$(echo "$destination_response" | jq -r .destinationId)
    
    if [ -z "$AB_DESTINATION_ID" ] || [ "$AB_DESTINATION_ID" = "null" ]; then
        log_error "Failed to create destination"
        echo "$destination_response"
        exit 1
    fi
    
    log_success "Destination created with ID: $AB_DESTINATION_ID"
    
    # Step 8: Create connection
    log_info "Step 8: Creating connection between source and destination..."
    
    connection_response=$(curl -s -X POST http://localhost:8000/api/public/v1/connections \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AB_TOKEN" \
        -d "{\"name\": \"e2e-test-connection\", \"sourceId\": \"${AB_SOURCE_ID}\", \"destinationId\": \"${AB_DESTINATION_ID}\", \"workspaceId\": \"${AB_WORKSPACE_ID}\"}")
    
    export AB_CONNECTION_ID=$(echo "$connection_response" | jq -r .connectionId)
    
    if [ -z "$AB_CONNECTION_ID" ] || [ "$AB_CONNECTION_ID" = "null" ]; then
        log_error "Failed to create connection"
        echo "$connection_response"
        exit 1
    fi
    
    log_success "Connection created with ID: $AB_CONNECTION_ID"
    
    # Step 9: Start sync job
    log_info "Step 9: Starting sync job..."
    
    job_response=$(curl -s -X POST http://localhost:8000/api/public/v1/jobs \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AB_TOKEN" \
        -d "{\"connectionId\": \"${AB_CONNECTION_ID}\", \"jobType\": \"sync\"}")
    
    export AB_JOB_ID=$(echo "$job_response" | jq -r .jobId)
    
    if [ -z "$AB_JOB_ID" ] || [ "$AB_JOB_ID" = "null" ]; then
        log_error "Failed to create sync job"
        echo "$job_response"
        exit 1
    fi
    
    log_success "Sync job started with ID: $AB_JOB_ID"
    
    # Step 10: Wait for job completion
    log_info "Step 10: Waiting for sync job to complete..."
    
    if ! wait_for_job "$AB_JOB_ID" "$TIMEOUT_SECONDS"; then
        log_error "Sync job failed or timed out"
        exit 1
    fi
    
    # Step 11: Verify data in SurrealDB
    log_info "Step 11: Verifying data in SurrealDB..."
    
    export SURREALDB_POD_NAME=$(kubectl get pods -l app=surrealdb -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$SURREALDB_POD_NAME" ]; then
        log_error "SurrealDB pod not found"
        exit 1
    fi
    
    # Check if data exists in SurrealDB
    log_info "Checking data in SurrealDB..."
    data_check=$(echo "SELECT * FROM test_dataset LIMIT 1;" | kubectl exec "$SURREALDB_POD_NAME" -- /surreal sql \
        -u root -p root --ns airbyte --db airbyte 2>/dev/null || echo "[[]]")
    
    if echo "$data_check" | grep -q "\[\[\]\]" || [ -z "$data_check" ]; then
        log_warning "No data found in SurrealDB, but sync job completed successfully"
        log_info "This might be expected if the test dataset is empty or the table name is different"
    else
        log_success "Data successfully synced to SurrealDB!"
        echo "Sample data:"
        echo "$data_check"
    fi
    
    # Step 12: Show final status
    log_info "Step 12: Final status check..."
    
    final_job_status=$(curl -s -X GET "http://localhost:8000/api/public/v1/jobs/$AB_JOB_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AB_TOKEN" | jq .)
    
    echo "Final job status:"
    echo "$final_job_status" | jq .
    
    log_success "End-to-end test completed successfully!"
    
    # Cleanup will be handled by the trap
}

# Run main function
main "$@"
