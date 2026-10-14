# System Design 2: Cloud image-processing platform

This design uses AWS to ingest images from a public API and an
engineer-managed Kafka stream, process them with existing containerized code,
retain image data for exactly seven days, and make current data available to
analysts.

Open [system-design-2.pptx](system-design-2.pptx) in PowerPoint, Keynote, or a
compatible presentation application for the end-to-end architecture diagram.

## Assumptions

- Image processing can be CPU- or memory-intensive; it therefore runs in
  containers rather than in the API service. Images are uploaded through the
  FastAPI service and streamed to object storage.
- Image upload sizes are within the configured API Gateway and
  `ImageUploaderService` request-size limits.
- The existing processing code can be packaged as a Docker image and is
  idempotent when given the same object key and processing version.
- The Kafka producers publish image payloads or references to images to an MSK
  topic. `KafkaStreamsHandler` is an engineer-managed Kafka Streams application
  on ECS; it consumes those records, validates and enriches the event, and
  writes the image and its metadata to the same ingress bucket used by the API
  upload path.
- Images and associated metadata are personal or sensitive data. They must not
  remain in raw, processed, metadata, analytics, backup, or BI extract storage
  after seven days.
- Analysts need aggregated and current seven-day data, not a permanent image
  archive. QuickSight uses Athena direct queries rather than an unbounded
  SPICE extract.

## End-to-end flow

1. The web application calls an HTTPS endpoint protected by CloudFront, AWS
   WAF, and API Gateway. `ImageUploaderService` is a FastAPI application on
   Amazon ECS that authorizes the request, validates the image, and streams it
   to the encrypted S3 ingress bucket.
2. Separately, engineers manage the Amazon MSK producers, topics, consumer
   configuration, and access. `KafkaStreamsHandler` runs on ECS, consumes the
   `image-upload-raw` topic, validates and enriches each image event, and
   writes the accepted image and event metadata directly into the same
   encrypted S3 ingress bucket.
3. S3 object-created events enter EventBridge and an SQS queue. SQS absorbs
   burst traffic and provides retry handling; messages that repeatedly fail go
   to a dead-letter queue for engineering investigation.
4. A Lambda dispatcher validates the event and starts
   `ImageProcessingTaskService`, a FastAPI-based processor on Amazon ECS. ECS
   workloads pull their versioned container images from Amazon ECR; the
   processing service scales compute workers based on queued jobs.
5. The processing job writes status, retry, and trace metadata to DynamoDB and
   writes a staging JSON metadata record to S3. The record includes the S3 path
   of the source image in the ingress bucket; it does not copy raw images.
6. An hourly AWS Glue ETL job reads the staging records, validates the schema,
   deduplicates by image and object version, and writes compacted Parquet to a
   dedicated S3 warehouse bucket. Each run creates an hourly partition,
   forming a rolling seven-day set of snapshots.
7. An AWS Glue **external table** catalogs only the curated Parquet in the S3
   warehouse bucket; it does not store image bytes. Athena queries that table
   and Amazon QuickSight provides BI dashboards through direct queries.
   Analyst roles can query curated metadata but have no raw-image bucket
   access.

## Diagram walkthrough: image data, metadata, and BI

The architecture diagram deliberately separates image bytes from metadata.
Only the ingress bucket holds image bytes. Every downstream analytics layer
works with metadata and S3 object paths, never a copied image.

| Layer in the diagram | Data held | Purpose | Downstream hand-off |
| --- | --- | --- | --- |
| S3 ingress bucket | Original image bytes and source event metadata | Seven-day compliant source of truth for both web and Kafka ingestion | S3 event to EventBridge/SQS; read by `ImageProcessingTaskService` |
| DynamoDB metadata | `image_id`, processing state, idempotency key, retry/error details, and `expires_at` | Operational status and duplicate-event protection; it is not the analytics store | Support, retry, and expiry controls |
| S3 metadata staging | One JSON processing record per image, including its ingress S3 path and extracted attributes | Durable hand-off between per-image processing and hourly ETL | Glue ETL reads new/changed records |
| S3 warehouse bucket | Validated, deduplicated Parquet metadata | Query-optimized analytical data, partitioned by processing hour | Glue external table reads this location |
| Glue table | Catalog schema and partition definitions only | Makes warehouse Parquet queryable by Athena; it stores no records or images | Athena view and QuickSight direct query |

### Hourly warehouse partitions

Each Glue ETL run writes one warehouse partition, for example:

```text
s3://image-warehouse/image_processing_metadata/
  processing_date=2026-10-14/
    processing_hour=17/
      part-0000.parquet
```

The Glue table is partitioned by `processing_date` and `processing_hour`.
Each Parquet record includes `image_id`, `source`, `ingress_image_s3_uri`,
`processing_status`, `processor_version`, `processed_at`, `expires_at`, and
the derived image attributes required for analysis. Glue ETL adds the new
partition and removes partitions outside the rolling seven-day window.

Athena exposes an analyst-facing view that filters on `expires_at` before
QuickSight queries it. This prevents BI access at the seven-day boundary even
while physical S3 lifecycle deletion completes asynchronously.

## Seven-day compliance retention

| Data location | Enforcement |
| --- | --- |
| S3 ingress bucket | Lifecycle rule permanently expires raw images and source metadata seven days after creation. Versioned bucket non-current versions and incomplete multipart uploads use matching expiry controls. |
| S3 metadata staging | Lifecycle rules permanently expire per-image JSON metadata records, including ingress-image S3 paths, after seven days. Replication destinations, if enabled, use the same rule. |
| S3 warehouse bucket | Lifecycle rules permanently expire curated Parquet partitions after seven days. Glue ETL writes one hourly partition per run and removes Glue catalog partitions outside the rolling seven-day snapshot window. Replication destinations, if enabled, use the same rule. |
| DynamoDB metadata | TTL is set to the image expiry timestamp. A scheduled compliance check alerts if TTL deletion is delayed. |
| Athena / Glue / QuickSight | Glue ETL removes catalog partitions older than seven days. Athena uses a dedicated workgroup with managed query results retained for 24 hours. QuickSight uses Athena direct query only; SPICE imports are disabled so BI does not retain a second dataset copy. |
| Queues and logs | SQS payloads hold object references, not image bytes, and expire within the seven-day policy. Logs redact object identifiers and do not record image content. |

Lifecycle expiration is asynchronous in S3 and DynamoDB. The system records an
expiry timestamp at ingest, prevents access after that time in the application,
and monitors deletion completion so privacy controls do not depend only on
background deletion timing.

## Security and least privilege

### Data at rest

- Use customer-managed KMS keys (CMKs), separated by raw images, processed
  data, and platform/operations data. Key policies permit only the workload
  roles that need decrypt access; analysts cannot decrypt raw-image data.
- Enable S3 Block Public Access, Bucket Owner Enforced object ownership,
  versioning, default SSE-KMS, and a bucket policy that denies `PutObject`
  without the approved KMS key. Apply the same controls to ingress, processed,
  Athena-results, replication, and log buckets.
- Encrypt MSK broker volumes, SQS and its DLQ, DynamoDB metadata, ECR images,
  CloudWatch logs, backups, and Athena results with their approved KMS keys.
  Enable ECR enhanced scanning and require immutable image digests or signed
  releases before ECS can run an image.

### Data in transit

- Enforce TLS 1.2 or later at CloudFront, API Gateway, `ImageUploaderService`,
  MSK clients, the Kafka Streams ECS service, service APIs, and analyst access.
  S3 bucket policies
  explicitly deny requests where `aws:SecureTransport` is false.
- Configure MSK client-to-broker communication as **TLS only**; do not permit
  plaintext or mixed TLS/plaintext listeners. Authenticate Kafka clients with
  IAM or mTLS and authorize topics with least-privilege ACLs.
- Keep ECS, Lambda, and MSK clients in private subnets. Use VPC endpoints
  for S3, ECR, KMS, Secrets Manager, CloudWatch, SQS, and STS so workloads do
  not need public internet routes. Security groups permit only required ports
  and source security groups.
- `ImageUploaderService` validates the authenticated user, object key, content
  type, size, and checksum before streaming an image to S3. No image bytes are
  placed in queue messages or application logs.

### Identity, authorization, and detection

- Separate AWS accounts/environments, AWS IAM Identity Center for engineers,
  workload IAM roles, and no shared static credentials. Secrets Manager stores
  and rotates the few application secrets that remain necessary.
- The API role can write only an allowed ingress prefix. The Kafka Streams ECS
  role can consume only approved MSK topics and write ingress data only. The
  image-processing ECS role can read the assigned ingress object and write its
  processed result/metadata. QuickSight can query curated Athena tables only.
- Enable CloudTrail management events plus S3 data events, AWS Config rules for
  encryption/public-access/TLS controls, GuardDuty, Security Hub, S3 access
  logs, and CloudWatch alarms for denied KMS/S3/MSK access and retention-policy
  failures.

## Scale, cost, and latency

- CloudFront/WAF/API Gateway and `ImageUploaderService` autoscale across
  multiple Availability Zones. The upload service streams image data to S3 and
  is sized for the configured upload-size limit.
- MSK runs across three Availability Zones. Engineers manage topics, ACLs,
  retention, consumer groups, and capacity; AWS manages broker infrastructure.
  MSK capacity/throughput is monitored and adjusted before saturation.
- SQS decouples ingestion from processing. ECS Service Auto Scaling scales the
  processing service from queue depth, avoids idle compute cost, and allows
  CPU/memory task profiles tailored to the image-processing workload. A
  serverless Glue ETL job runs hourly to compact staged records, reducing
  Athena scan cost and small-file overhead.
- S3 Intelligent-Tiering is unnecessary for a seven-day window; standard S3
  plus expiration is simpler and lower risk. Parquet metadata limits Athena
  scan cost. Budgets, tagging, Cost Anomaly Detection, and per-service alarms
  control spend.

## Availability, fault tolerance, and disaster recovery

- S3, DynamoDB, SQS, EventBridge, ECR, API Gateway, and Lambda are managed
  regional services; MSK uses three Availability Zones. Stateless API and
  processing workloads are deployed across multiple AZs.
- Queue retries, idempotency keys, job state in DynamoDB, and DLQs make failed
  processing recoverable without duplicate output. CloudWatch alarms page
  engineers for queue age, DLQ depth, failed jobs, connector lag, and retention
  policy failures.
- Infrastructure is defined with Terraform or CloudFormation and deployed by
  CI/CD. ECR image digests, source versions, Glue ETL versions, and Glue table
  definitions are traceable. Processing code is tested, scanned, and promoted
  through separate environments.
- Because compliance prohibits retaining raw content after seven days, disaster
  recovery restores infrastructure and code—not expired image data. While data
  is inside its allowed window, optional cross-region replication can be used
  only if the replica has equivalent encryption and seven-day deletion rules.

## Operations and maintenance

- Engineers own MSK topic configuration, the Kafka Streams ECS service, schema
  compatibility, consumer lag, and on-call runbooks.
- Platform engineers own infrastructure-as-code modules, patching base images,
  CI/CD, AWS account guardrails, and cost/security observability.
- Application engineers own the image-processing container, versioned contract,
  test corpus, and retry/idempotency behavior.
- Runbooks cover poison messages, replaying a valid object event before its
  expiry, Kafka Streams recovery, Glue ETL failure/replay, KMS key incidents,
  and evidence of retention enforcement.
