### 4. Run MPI application (OpenFOAM) via Azure CLI


Download bash script:

```
git clone https://github.com/marconetto/2024hpcsummitv1.git
cd 2024hpcsummitv1/batchmpicli
```

Run simple mpi show nodes app:

```
./batch_shownodes.sh -g myresourcegroup1
```


Run openfoam+mpi app:

```
./batch_openfoam.sh -g myresourcegroup2
```

Storage account will follow the name `<myresourcegroup>sa`. So choose a resource
group name that will not generate conflict. You can choose for instance
`<yourlastname><year><month><day><deploymentversion>`.

Copy the task results to local machine via ``scp`` to jumpbox VM, ``azcopy``, or
[Azure Storage Explorer ](https://azure.microsoft.com/en-us/products/storage/storage-explorer).
You may need to add a DNS entry in your local machine to solve the private IP of the storate account
endpoint.

```
azcopy login
azcopy copy <Blob SAS URL> "mydata"
```


Delete resource groups:

```
az group delete -g myresourcegroup
```

Visualize the results with paraview. Link to [download](https://www.paraview.org/download/).


<p align="center" width="100%">
   <img width="75%" src="paraviewimage.png">
</p>

