resource "terraform_data" "db_a" {
  input = "db-a v2"
}

output "db_a" {
  value = terraform_data.db_a.output
}
