resource "terraform_data" "db_b" {
  input = "db-b v1"
}

output "db_b" {
  value = terraform_data.db_b.output
}
