## 2. Create Azure Batch resources in Azure Portal 

### Batch service

1. Go to Marketplace and create a Batch service. 
2. On the "New batch account" page, choose the subscription. 
3. Create a new Resource group called "yourinitials"-HPCSummitBatchDemo
4. Enter the account name as "yourinitials"hpcbatchdemoaccount
5. Choose the location to be **East US**
6. Review and Create. 

### Pool

1. Open the deployed batch account and select the **Pools** option from the left navigation pane. 
2. Click on **+Add** 
3. Enter the pool ID as "yourinitials"-hpcbatchdemopool
4. Select publisher: canonical, offer: Ubuntu Server 22.04 LTS, Sku: 22_04-lts
5. Choose VM size as "Standard_D2s_v3 - 2 vCPUs, 8GB Memory" 
6. Increase Target dedicated nodes to 2
7. Enable Start Task
8. Enter the following command line 

```
/bin/bash -c "sudo apt-get update && sudo apt-get install -y ffmpeg"
```

**Note**: ffmpeg will be used for next section.

9. Select the Elevation level - Pool autouser, Admin'
10. Set Wait for success to True
11. Click OK. This triggers the action of Creation of Pool. You will see that the pool immideately goes to "resizing" in Allocation state. 
12. Go to pool to check the progress of pool creation. 

### Job
1. From the left navigation pane, go to Jobs and add a job
2. Name the job as "yourinitials"-hpcbatchdemojob
3. Select the pool that we created
4. Click OK

### Task

1. Go to the recently created Job and create a task. 
2. Name the task as task1
3. Enter a command line as 

```
echo "Hello world -- I am task1 "
```

4. View the output of the task in stdout.txt


