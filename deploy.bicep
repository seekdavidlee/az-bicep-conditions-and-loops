// See: https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/loops

param stackPrefix string
param stackEnvironment string
param priLocation string = 'centralus'
param drLocation string = 'eastus2'
param sourceIP string

var stackName = '${stackPrefix}${stackEnvironment}'

var tags = {
  'stack-name': 'platform-networking'
  'stack-environment': stackEnvironment
}

var subnets = [
  {
    name: 'appgw'
    priPrefix: '10.0.0.0/24'
    drPrefix: '172.0.0.0/24'
  }
  {
    name: 'app'
    priPrefix: '10.0.1.0/24'
    drPrefix: '172.0.1.0/24'
  }
  {
    name: 'db'
    priPrefix: '10.0.2.0/24'
    drPrefix: '172.0.2.0/24'
  }
]

resource priVnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: '${stackName}-pri-centralus'
  tags: tags
  location: priLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [for (subnet, i) in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.priPrefix
      }
    }]
  }
}

resource drVnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: '${stackName}-dr-eastus2'
  tags: tags
  location: drLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '172.0.0.0/16'
      ]
    }
    subnets: [for (subnet, i) in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.drPrefix
      }
    }]
  }
}

resource priPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  name: 'pri-to-dr-peer'
  parent: priVnet
  properties: {
    allowVirtualNetworkAccess: true
    remoteVirtualNetwork: {
      id: drVnet.id
    }
  }
}

resource drPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  name: 'dr-to-pri-peer'
  parent: drVnet
  properties: {
    allowVirtualNetworkAccess: true
    remoteVirtualNetwork: {
      id: priVnet.id
    }
  }
}

var allowHttp = {
  name: 'AllowHttp'
  properties: {
    description: 'Allow HTTP'
    priority: 100
    protocol: 'Tcp'
    direction: 'Inbound'
    access: 'Allow'
    sourceAddressPrefix: sourceIP
    sourcePortRange: '*'
    destinationPortRange: '80'
    destinationAddressPrefix: '*'
  }
}

// See: https://docs.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure#network-security-groups
var allowAppGatewayV2 = {
  name: 'AllowApplicationGatewayV2Traffic'
  properties: {
    description: 'Allow Application Gateway V2 traffic'
    priority: 140
    protocol: 'Tcp'
    direction: 'Inbound'
    access: 'Allow'
    sourceAddressPrefix: 'GatewayManager'
    sourcePortRange: '65200-65535'
    destinationPortRange: '*'
    destinationAddressPrefix: '*'
  }
}

resource priNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = [for subnet in subnets: {
  name: '${stackName}-pri-${subnet.name}-subnet-nsg'
  location: priLocation
  tags: tags
  properties: {
    securityRules: (subnet.name == 'appgw') ? [
      allowHttp
      allowAppGatewayV2
    ] : []
  }
}]

resource drNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = [for subnet in subnets: {
  name: '${stackName}-dr-${subnet.name}-subnet-nsg'
  location: drLocation
  tags: tags
  properties: {
    securityRules: (subnet.name == 'appgw') ? [
      allowHttp
      allowAppGatewayV2
    ] : []
  }
}]

// Note that all changes related to the subnet must be done on this level rather than
// on the Virtual network resource declaration above because otherwise, the changes
// may be overwritten on this level.

@batchSize(1)
resource priSubnets 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = [for (subnet, i) in subnets: {
  name: '${priVnet.name}/${subnet.name}'
  properties: {
    addressPrefix: subnet.priPrefix
    networkSecurityGroup: {
      id: priNSG[i].id
    }
    serviceEndpoints: (subnet.name == 'app') ? [
      {
        service: 'Microsoft.Sql'
        locations: [
          priLocation
        ]
      }
    ] : (subnet.name == 'appgw') ? [
      {
        service: 'Microsoft.Web'
        locations: [
          priLocation
        ]
      }
    ] : []
  }
}]

@batchSize(1)
resource drSubnets 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = [for (subnet, i) in subnets: {
  name: '${drVnet.name}/${subnet.name}'
  properties: {
    addressPrefix: subnet.drPrefix
    networkSecurityGroup: {
      id: drNSG[i].id
    }
    serviceEndpoints: (subnet.name == 'app') ? [
      {
        service: 'Microsoft.Sql'
        locations: [
          priLocation
        ]
      }
    ] : (subnet.name == 'appgw') ? [
      {
        service: 'Microsoft.Web'
        locations: [
          priLocation
        ]
      }
    ] : []
  }
}]
