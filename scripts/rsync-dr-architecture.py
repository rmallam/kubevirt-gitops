from diagrams import Cluster, Diagram, Edge, Node
from diagrams.onprem.compute import Server
from diagrams.k8s.compute import Pod
from diagrams.programming.language import Python
from diagrams.onprem.network import Nginx
from diagrams.generic.storage import Storage
from diagrams.generic.os import LinuxGeneral
from diagrams.onprem.client import Client
from diagrams.custom import Custom

# Define some custom styling
graph_attr = {
    "fontsize": "20",
    "bgcolor": "white",
    "rankdir": "TB",  # Top to bottom layout
    "pad": "0.75",
    "splines": "ortho",
    "nodesep": "2.5",  # Increased for more horizontal space
    "ranksep": "1.2",
    "margin": "0.75",
}

node_attr = {
    "fontsize": "12",
    "margin": "0.6",
    "width": "1.5",
    "height": "1.5",
}

edge_attr = {
    "fontsize": "10",
}

# Create the diagram with wider layout
with Diagram("Fedora VM with EFS DR Architecture", show=True, 
             graph_attr=graph_attr, node_attr=node_attr, edge_attr=edge_attr,
             direction="TB", outformat="png", filename="fedora_vm_with_efs_dr_architecture"):
    
    # Define external client at the top middle
    client = Client("External Users")
    
    # Define OpenShift icon path - use local file
    openshift_icon = "/Users/rakeshkumarmallam/kubevirt-gitops/openshift-icon.png"
    
    # Create clusters with increased spacing
    # Primary Site Cluster
    with Cluster("Primary Site - OpenShift Virtualization"):
        ocp1 = Custom("OpenShift Container Platform", openshift_icon)
        
        with Cluster("Virtual Machines"):
            # Create VMs side by side
            with Cluster(""):
                # First column - Python App VM
                fedora1 = LinuxGeneral("Fedora VM")
                app1 = Python("Python App (Active)")
                
                # Stack vertically
                fedora1 >> app1
            
            # Second column - RSYNC VM
            with Cluster(""):
                rsync_vm1 = LinuxGeneral("Fedora VM")
                rsync1 = Server("RSYNC Service")    
                
                # Stack vertically
                rsync_vm1 >> rsync1 
        
        # Storage at the bottom
        efs1 = Storage("EFS Storage")
        
        # Connect components
        app1 >> Edge(label="Write Logs") >> efs1
        rsync1 << Edge(label="Monitor & Read") << efs1
    
    # DR Site Cluster
    with Cluster("DR Site - OpenShift Virtualization"):
        ocp2 = Custom("OpenShift Container Platform", openshift_icon)
        
        with Cluster("Virtual Machines"):
            # Create VMs side by side
            with Cluster(""):
                # First column - Python App VM (standby)
                fedora2 = LinuxGeneral("Fedora VM")
                app2 = Python("Python App (Standby)")
                
                # Stack vertically with dashed line to indicate standby
                fedora2 >> Edge(style="dashed") >> app2
            
                # Second column - RSYNC VM
                with Cluster(""):
                    rsync_vm2 = LinuxGeneral("Fedora VM")
                    rsync2 = Server("RSYNC Service")
                
                # Stack vertically
                rsync_vm2 >> rsync2 
        
        # Storage at the bottom
        efs2 = Storage("EFS Storage")
        
        # Connect components
        app2 >> Edge(label="Write Logs", style="dashed") >> efs2
        rsync2 << Edge(label="Monitor & Read") << efs2

    # Connect the two sites with bidirectional sync
    rsync1 >> Edge(label="sync Logs", style="thick") >> rsync2
    
    # Add external client connections
    client >> Edge(label="Primary Traffic", color="blue") >> app1
    client >> Edge(label="DR Traffic (When Primary Down)", style="dashed", color="red") >> app2
    
    # Connect OpenShift to the VMs
    ocp1 - Edge(color="transparent") - fedora1
    ocp1 - Edge(color="transparent") - rsync_vm1
    ocp2 - Edge(color="transparent") - fedora2
    ocp2 - Edge(color="transparent") - rsync_vm2
