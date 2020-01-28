# Default controls for bob's infra experiments

# Notes on absent resources: Some resources are tested upstream, while others are tested
# implicitely by others; For example, the main VPC module is tested upstream, and retesting
# it here would provide little to no value.

control 'default' do
  desc 'Validate that bob\'s infra is complete'

  describe aws_iam_role(attribute('bastion_iam_role_name')) do
    it { should exist }
    its('attached_policies_names') { should cmp [attribute("bastion_iam_policy_name")] }
  end

  describe aws_iam_role(attribute('goiardi_iam_role_name')) do
    it { should exist }
    its('attached_policies_names') { should cmp [attribute('goiardi_extra_iam_policy_name')] }
  end

  describe aws_s3_bucket(attribute('static_assets_bucket_id')) do
    it { should exist }
    it { should_not be_public }
  end

  describe aws_security_group(attribute('req_db_sg_id')) do
    it { should exist }
    its('inbound_rules_count') { should cmp 0 }
    its('outbound_rules_count') { should cmp 0 }
  end

  describe aws_security_group(attribute('bastion_sg_id')) do
    it { should exist }
    it { should allow_in_only(port: 22, protocol: 'tcp', ipv4_range: '0.0.0.0/0') }
  end

  describe aws_security_group(attribute('goiardi_sg_id')) do
    it { should exist }
    it { should allow_in_only(port: 22, protocol: "tcp", position: 2, security_group: attribute('bastion_sg_id')) }
    it { should allow_in_only(port: 80, protocol: "tcp", position: 1, security_group: attribute('main_alb_sg_id')) }
  end

  describe aws_security_group(attribute('main_alb_sg_id')) do
    it { should exist }
    it { should allow_in_only(port: 443, protocol: "tcp", ipv4_range: '0.0.0.0/0') }
  end

  describe aws_alb(attribute('main_alb_arn')) do
    it { should exist }
    its('zone_names.count') { should be >= 3 }
    its('security_groups') { should cmp [attribute('main_alb_sg_id')] }
    its('scheme') { should cmp 'internet-facing' }
    its('vpc_id') { should cmp attribute('main_vpc_id') }
  end

  describe aws_security_group(attribute('main_postgres_sg_id')) do
    it { should exist }
    it { should allow_in_only(port: 5432, protocol: "tcp", security_group: attribute('req_db_sg_id')) }
  end
end
