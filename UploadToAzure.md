# Upload files to Azure 

## From the portal

Log in to your Azure Account:

<img src="https://github.com/AzureCAT-GSI/SAP-HANA-ARM/blob/master/media/Upload1.png" height="480">

Click on create a resource:

<img src="https://github.com/AzureCAT-GSI/SAP-HANA-ARM/blob/master/media/Upload2.png" width="240">

Type in storage account and click on Storage Account - blob, file, table, queue:


<img src="https://github.com/AzureCAT-GSI/SAP-HANA-ARM/blob/master/media/Upload3.png" width="600">

Click on Create:

<img src="https://github.com/AzureCAT-GSI/SAP-HANA-ARM/blob/master/media/Upload4.png" height="480">

Fill in the required information and click create. The name of the storage account has to be unique and only accepts lowercase letters and numbers:


<img src="https://github.com/AzureCAT-GSI/SAP-HANA-ARM/blob/master/media/Upload5.png" height="480">

Once the deployment has completed click on Go to resource:

<img src="https://github.com/AzureCAT-GSI/SAP-HANA-ARM/blob/master/media/Upload6.png" width="480">

Click on Blobs:

<img src="https://github.com/AzureCAT-GSI/SAP-HANA-ARM/blob/master/media/Upload7.png" height="480">

Click on Container and configure a container Name. Make sure to change the Access level to Blob

<img src="https://github.com/AzureCAT-GSI/SAP-HANA-ARM/blob/master/media/Upload8.png" width="480">

To upload the files as indicated in the README.md click on Upload, expand the Advanced option and use the Upload to folder option to create the SapBits folder.

<img src="https://github.com/AzureCAT-GSI/SAP-HANA-ARM/blob/master/media/Upload9.png" height="480">

If you wish to install the jumpbox with HANA Studio, navigate to the SapBits folder and use the same procedure to create the SAP_HANA_STUDIO folder.
