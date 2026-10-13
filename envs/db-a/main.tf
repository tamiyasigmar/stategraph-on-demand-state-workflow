resource "terraform_data" "db_a" {
  input = "db-a v1"
}

output "db_a" {
  value = terraform_data.db_a.output
}
