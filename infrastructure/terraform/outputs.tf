output "vpc_id" {
  value = aws_vpc.posduif.id
}

output "db_endpoint" {
  value = aws_db_instance.posduif.endpoint
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.posduif.cache_nodes[0].address
}

output "sync_engine_public_ip" {
  value = aws_instance.sync_engine.public_ip
}



