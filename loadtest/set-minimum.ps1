param(
    [Parameter(Mandatory)][ValidateRange(1, 2)][int]$Tasks
)

$ErrorActionPreference = 'Stop'
$infra = Join-Path (Split-Path $PSScriptRoot -Parent) 'infra'
function Get-TerraformOutput([string]$Name) {
    $value = terraform "-chdir=$infra" output -raw $Name
    if ($LASTEXITCODE -ne 0 -or !$value) { throw "Cannot read Terraform output $Name" }
    return $value
}

$region = Get-TerraformOutput 'aws_region'
$cluster = Get-TerraformOutput 'ecs_cluster_name'
$service = Get-TerraformOutput 'ecs_service_name'
$resource = "service/$cluster/$service"

aws application-autoscaling register-scalable-target --region $region --service-namespace ecs `
    --resource-id $resource --scalable-dimension 'ecs:service:DesiredCount' `
    --min-capacity $Tasks --max-capacity 3 --no-cli-pager
if ($LASTEXITCODE -ne 0) { throw 'Cannot change ECS minimum capacity' }

aws application-autoscaling describe-scalable-targets --region $region --service-namespace ecs `
    --resource-ids $resource --query 'ScalableTargets[0].{Minimum:MinCapacity,Maximum:MaxCapacity}' `
    --output table --no-cli-pager
if ($LASTEXITCODE -ne 0) { throw 'Cannot verify ECS capacity limits' }
