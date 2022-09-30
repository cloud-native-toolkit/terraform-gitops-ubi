
resource local_file write_outputs {
  filename = "gitops-output.json"

  content = jsonencode({
    name        = module.gitops_ubi.name
    branch      = module.gitops_ubi.branch
    namespace   = module.gitops_ubi.namespace
    server_name = module.gitops_ubi.server_name
    layer       = module.gitops_ubi.layer
    layer_dir   = module.gitops_ubi.layer == "infrastructure" ? "1-infrastructure" : (module.gitops_ubi.layer == "services" ? "2-services" : "3-applications")
    type        = module.gitops_ubi.type
  })
}
