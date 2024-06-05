# 2024 HPC Summit - Azure Batch Lab


**Session goal.** Become familiar with concepts of Azure Batch, have hands-on
experience with this service, and be exposed to an end-2-end application running
on it.


### 1. Overview of Azure Batch (10min)

- What is batch and its capabilities?
- How does it compare with CycleCloud, AKS, VMSS?
- Azure Batch interaction: Azure Portal, CLI, SDK, ARM, Bicep, TerraForm
- Further reading references

SLIDES [HERE](./azure_batch.pptx)


### 2. Hello world task via Azure Portal (20min)

- Show creation of resource group, storage account, and batch service
- Execute task: simple `echo "Hello World"` to stdout
- 1 pool, 1 job, 4 tasks for a simple SKU
- Show visualization the output of each task executed

LINK: [HERE](basicjob/README.md)


### 3. Embarrassingly parallel application via Azure Portal (10min)

- Target app: ffmpeg
- Have some app input from git repository
- Move the input and app to the blob
- Run app with 4 tasks and store the output also in blob

LINK: [HERE](paralleljob/README.md)


### 4. Run MPI application (OpenFOAM) via Azure CLI (10min)

- Target app: OpenFOAM (computational fluid dynamics)
- Highlight the use of azure batch StartTask
- Highlight the use of resource monitoring

Details: [HERE](./batchmpicli/README.md)

### 5. Demo: end-2-end application via Python SDK (10min)

- Show motivation of this tool
- Show video demo
- Show internals:
    - reliability when provisioning nodes
    - dynamic resizing of pools
    - custom images

LINK to HPCAdvisor: [HERE](https://azure.github.io/hpcadvisor/)


NOTES:

You may also need to accept the terms of using almalinux images:

```
az vm image terms accept --publisher almalinux --offer almalinux-hpc --plan 8_6-hpc-gen2
```

You may need to enable batch to have contributor access to the subscription:

```
SUBID=`az account show | jq -r '.id'` ; az role assignment create --assignee ddbf3205-c6bd-46ae-8127-60eb93363864 --role contributor --scope "/subscriptions/$SUBID"
```


