from boto3 import client


class DynamicInventory:
    @property
    def __client(self):
        return client('ec2', region_name='us-east-1')

    def get_instances(self, instances, next_token=None):
        filters = [
            {
                'Name': 'instance-state-name',
                'Values': [
                    'running',
                ]
            }
        ]
        if next_token:
            response = self.__client.describe_instances(
                NextToken=next_token, Filters=filters)
        else:
            response = self.__client.describe_instances(Filters=filters)
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                if instance['Tags'][0]['Key'] == 'Name':
                    if not instances.get(instance['Tags'][0]['Value']):
                        instances.update(
                            {
                                instance['Tags'][0]['Value']: [
                                    instance['PublicIpAddress']
                                ]
                            }
                        )
                    else:
                        instances[instance['Tags'][0]['Value']].append(
                            instance['PublicIpAddress'])
        if response.get('NextToken'):
            self.get_instances(instances, next_token=response['NextToken'])
        return instances

    def create_hosts_file(self, instances):
        with open('/tmp/hosts.cfg', 'a') as f:
            for k, v in instances.items():
                f.write(f'[{k}]\n')
                f.write('\n'.join(v))
                f.write('\n')


if __name__ == '__main__':
    inventory = DynamicInventory()
    all_instances = inventory.get_instances({})
    inventory.create_hosts_file(all_instances)
    print(all_instances)
