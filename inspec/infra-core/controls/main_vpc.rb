title "AWS Core Terraform module"

main_vpc_id = input("main_vpc_id")

control "aws-core-1" do
  impact 1.0
  title "The main VPC exists and is available."

  describe aws_vpc(main_vpc_id) do
    it { should exist }
    it { should be_available }
  end
end

