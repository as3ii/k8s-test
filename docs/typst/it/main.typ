#let en(body) = text(lang: "en", [#{ body }])

Nota: questo documento prevede che il lettore possieda già conoscenze
superficiali sulla terminologia e struttura di un cluster Kubernetes. Vedasi
documentazione ufficiale in merito: https://kubernetes.io/docs/concepts/

= Sommario

Il progetto ha come scopo il realizzare un #en[cluster] Kubernetes tramite
macchine virtuali su un #en[hypervisor] (come #link(
  "https://www.proxmox.com/en/products/proxmox-virtual-environment/overview",
)[ProxmoxVE]), per simulare condizioni simili ad un ambiente per l'#en[edge
  computing] nel quale si vuole minimizzare la dipendenza da risorse in
#en[cloud] e allo stesso tempo minimizzare l'hardware richiesto. Si è quindi
scelto di usare #link("https://k3s.io/")[`k3s`] su tre nodi configurati per
ospitare anche il #en[control plane] in alta disponibilità, con la possibilità
di aggiungere in futuro altri nodi "#en[worker]". Sul cluster tra i servizi
essenziali risaltano #link("https://kube-vip.io/")[`kube-vip`] per la gestione e
assegnazione di IP virtuali, #link("https://traefik.io/traefik")[Traefik] come
#en[reverse proxy] e #en[load balancer], #link(
  "https://kubernetes-sigs.github.io/external-dns/latest/",
)[`external-dns`] per la gestione automatizzata di record DNS in un server DNS
autoritativo esterno al cluster per permettere il raggiungimento dei servizi
senza usare IP, #link(
  "https://cert-manager.io/",
)[`cert-manager`] per la creazione e gestione di certificati TLS, e #link(
  "https://github.com/kubernetes-csi/csi-driver-nfs",
)[`csi-driver-nfs`] per poter fornire spazio di archiviazione condiviso da tutti
i nodi.

= Infrastruttura

== Hardware <infra_hardware>
Questo progetto è stato realizzato utilizzando un mini PC con un Intel N95, 8GB
di RAM e un SSD da 250GB, e un #en[router]/#en[switch] (in questo caso un
MikroTik hAP ac², un piccolo #en[router] di fascia #en[prosumer], ma la maggior
parte dei #en[router] casalinghi sarebbe stato sufficiente per questo progetto).
Sul mini PC è stato installato un #en[hypervisor] per poter virtualizzare e
gestire le macchine e i servizi necessari. Il #en[router] deve solo permettere
il traffico tra i dispositivi locali e in uscita verso internet, permettere la
configurazione del range utilizzabile dal server DHCP e permettere la
configurazione di un server DNS esterno.

== Software e servizi <infra_software>
Il mini PC utilizza come #en[hypervisor] ProxmoxVE 9.1, distribuzione Linux
basata su Debian 13 che permette di gestire in maniera semplificata macchine
virtuali e #en[container] LXC sia via SSH che tramite un'interfaccia web e delle
API utilizzabili tramite software terzi. Sia le macchine virtuali che i
#en[container] LXC impiegati utilizzano Debian 13 come base. Per le
caratteristiche dettagliate delle macchine virtuali vedasi @cluster_hardware.
Per il supporto al #en[cluster] sono state creati 2 #en[container] LXC: uno
ospita un server DNS e l'altro un server NFS. Nel dettaglio il primo
#en[container] utilizza #link("https://technitium.com/dns/")[Technitium], un
server DNS che si occupa della risoluzione di domini generici e gestisce una
zona DNS per un (sotto)dominio utilizzabile solo dalla rete LAN e configurabile
tramite #link("https://www.rfc-editor.org/rfc/rfc2136")[RFC2136]. #link(
  "https://www.isc.org/bind/",
)[BIND9] sarebbe un ottima alternativa più minimale, ma avrebbe richiesto più
tempo per una corretta configurazione, un'altra opzione richiederebbe l'uso
diretto di un server DNS autoritativo pubblicamente accessibile come Cloudflare
anche se creerebbe una dipendenza da servizi in #en[cloud]. L'altro
#en[container] ha un volume montato (per facilitarne i backup) accessibile dalla
rete LAN tramite un server NFS, utilizzabile come se fosse un NAS per avere
spazio di archiviazione condiviso tra più dispositivi.

== #en[Provisioning] <infra_provisioning>
Il #en[provisioning] è stato gestito principalmente tramite #link(
  "https://opentofu.org/",
)[OpenTofu], fork di #link(
  "https://developer.hashicorp.com/terraform",
)[Terraform] ospitato dalla Linux Foundation, e #link(
  "https://docs.ansible.com",
)[Ansible]. OpenTofu è stato utilizzato principalmente per la creazione tramite
le API di ProxmoxVE di container LXC e macchine virtuali, e relativi record DNS
(gestiti via RFC2136) utili a identificarli e per semplificare l'accesso ad
essi. Ansible è stato utilizzato principalmente per configurare i container LXC
e le macchine virtuali, in particolare gestire aggiornamenti del OS, installare
e configurare programmi, copiare file e scaricarli da internet. Le istruzioni
per effettuare il #en[provisioning] del #en[cluster] sono riportate nel file
#link(
  "https://github.com/as3ii/k8s-test/blob/master/README.md",
)[`README.md`].

== Limitazioni e possibili miglioramenti <infra_improvement>
L'hardware attuale è abbastanza limitante sopratutto in termini di RAM, che
impone una soglia massima sia alla quantità di RAM assegnata ai singoli nodi
virtualizzati che al numero stesso di nodi. ProxmoxVE e senza alcun carico di
lavoro consuma circa 1GB di RAM, assegnando 2GB per 3 VM comporta che per
eventuali altri servizi e per la cache rimane meno di 1GB di RAM utilizzabile.
Secondariamente, avere dei core aggiuntivi migliorerebbe le performance non
dovendo obbligare le VM a condividere gli stessi #en[core]. In alternativa è
possibile impiegare 3 dispositivi simili al mini PC utilizzato per creare un
#en[cluster bare metal], dove quindi ogni dispositivo fisico corrisponde a un
nodo del cluster senza richiedere la virtualizzazione di risorse, e aumentando
le risorse complessive disponibili al cluster. Nel caso si voglia mantenere un
#en[hypervisor] per suddividere in più macchine virtuali l'hardware è possibile
creare un #en[cluster] ProxmoxVE, cosa che ridurrebbe la fragilità intrinseca di
un sistema composto da una singola macchina, permettendo la migrazione di VM tra
nodi fisici nel caso di manutenzione programmata e, nel caso si utilizzi un NAS
non virtualizzato o Ceph come filesystem (vedasi @cluster_storage) e si
verifichi un guasto a un macchina fisica, la creazione automatica di VM
identiche a quelle presenti nel dispositivo guasto all'interno dei restanti
#en[hypervisor].

= Architettura del cluster

== Hardware e base del #en[cluster] <cluster_hardware>
Ognuno dei nodi corrisponde ad una macchina virtuale con 2 vCPU, 2GB di RAM e
5GB di storage. I nodi utilizzano Debian 13, su cui è stato installato e
configurato `k3s` disattivando `servicelb` e `traefik` presenti di default,
sostituiti con servizi discussi nelle prossime sezioni. Il cluster in idle ma
con già presenti tutti i servizi necessari consuma circa

== Rete <cluster_network>
Il server DHCP del #en[router] è impostato per indicare come server DNS il
server custom discusso in @infra_software, e per distribuire solo parte degli IP
della #en[subnet] /24 utilizzata, questo per permettere di assegnare un IP
statico a ognuno dei nodi e agli altri servizi esposti rete (come il server DNS
e NFS).

Nel #en[cluster] è stato installato #link("https://kube-vip.io/")[`kube-vip`]
come `DaemonSet` #footnote[per avere una istanza del #en[pod] per nodo, vedasi
  #link(
    "https://kube-vip.io/docs/installation/daemonset/",
  )[documentazione kube-vip] per maggiori dettagli], servizio utilizzato per il
gestire "IP virtuali" e bilanciamento del carico per #en[control plane] e
servizi di tipo `LoadBalancer` senza richiedere hardware esterno. Le istanze di
`kube-vip` sono configurate per eleggere un nodo come "#en[leader]", che avrà il
compito di assegnare alla propria interfaccia di rete gli IP aggiuntivi e
inviare in #en[broadcast] pacchetti ARP per segnalare alla rete quali IP il nodo
sta gestendo. Nel caso il nodo #en[leader] vada #en[offline], gli altri nodi
eleggeranno un altro #en[leader] così da rendere nuovamente disponibili i
servizi esposti alla rete dal cluster e garantire l'alta disponibilità.
`kube-vip` è configurato per esporre un IP statico dedicato al #en[control
  plane], e tramite #link(
  "https://github.com/kube-vip/kube-vip-cloud-provider",
)[`kube-vip-cloud-provider`] può assegnare IP dedicati a servizi di tipo
`LoadBalancer`.

Vedasi @cluster_services per altri servizi installati per gestire i #en[layer]
superiori dello #en[stack] di rete.

== Spazio di archiviazione <cluster_storage>
Il disco di ogni nodo viene utilizzato dal #en[cluster] per il database
distribuito `etcd`, utilizzato dal #en[control plane] per memorizzare lo stato
del cluster, e per memorizzare le immagini dei container. Può essere utilizzato
dai #en[container stateful] per memorizzare i loro dati, ma è sconsigliato in
quanto nel caso un nodo vada #en[offline] gli altri nodi ricreerebbero il
#en[container] con il relativo volume *vuoto*, non conoscendo il contenuto
precedente. Per questo sul cluster è stato installato #link(
  "https://github.com/kubernetes-csi/csi-driver-nfs",
)[`csi-driver-nfs`], configurato per permettere la creazione di volumi su un
server NFS esterno al #en[cluster] accessibile contemporaneamente da tutti i
nodi. Nel dettaglio, sono stati configurate due `StorageClass` con valori
leggermente differenti: uno impostato per cancellare il volume e i file al suo
interno non appena il `PersistentVolumeClaim` viene eliminato, l'altro impostato
per mantenere i dati nel caso il `PersistentVolumeClaim` venga ricreato uguale
al precedente.

== Servizi <cluster_services>
Traefik è stato scelto come principale #en[application load balancer] e
#en[reverse proxy], si occupa quindi di gestire tutto il traffico in ingresso
tramite le porte 80 e 443, inoltrandolo alle giuste applicazioni sulla base del
URL ed eventualmente eseguire ridirezioni, modificare header, e aggiungere TLS
ad applicazioni che espongono risorse solo via HTTP. Traefik è stato configurato
per caricare dinamicamente le impostazioni per esporre applicazioni osservando
le risorse di tipo `Ingress`, `Gateway` e le risorse #en[custom] come
`Middleware` e `IngressRoute`. La gestione dei certificati per HTTPS può essere
fatta a mano fornendo i certificati a Traefik usando i `Secret`, ma è
consigliabile utilizzare #link("https://cert-manager.io/")[`cert-manager`] per
automatizzare la generazione di certificati `LetsEncrypt` sfruttando un dominio
reale e il relativo server DNS pubblico. Infine, tramite #link(
  "https://kubernetes-sigs.github.io/external-dns/latest/",
)[`external-dns`] è possibile gestire in maniera dichiarativa, tramite
annotazioni, i record DNS `A` o `CNAME` da creare per poter accedere a servizi
senza dover ricordare indirizzi IP.

== Limitazioni e miglioramenti possibili <cluster_improvement>

=== Hardware VM
Come introdotto in @infra_improvement, aumentare la RAM disponibile on ogni nodo
del cluster sarebbe una buona cosa: al momento, ogni nodo in idle utilizza
minimo 1.3GB di RAM e circa il 10% delle 2 vCPU utilizzabili, in queste
condizioni un qualsiasi picco di utilizzo RAM o il #en[deployment] di altri pod
potrebbe far scattare meccanismi gestiti da Kubernetes per l'#en[eviction] di
pod (comportandone la migrazione in altri nodi, cosa che potrebbe non risolvere
il problema, solo spostarlo e potenzialmente creando un loop), o direttamente i
sistemi interni al #en[kernel] che procedono con l'uccidere uno o più processi
che stanno causando l'alta "#en[memory pressure]".

=== Network
Al momento il traffico interno al cluster non lascia mai il #en[bridge] gestito
da ProxmoxVE nel mini PC, nel caso si scalasse su più macchine fisiche sarebbe
opportuno utilizzare VLAN diverse per separare il traffico interno al cluster da
quello proveniente dal esterno. Un'altra miglioria, che potrebbe migliorare pure
la distribuzione del carico tra i nodi è il riconfigurare `kube-vip` per
eleggere un #en[leader] diverso per ogni `LoadBalancer`. Come alternativa, nel
caso il router lo supporti, si potrebbe configurare `kube-vip` per utilizzare
BGP invece di ARP, ottenendo quindi vero bilanciamento del carico sfruttando il
router e le rotte BGP per emulare il comportamento di un #en[cloud load
  balancer].

=== Storage
Lo storage di un cluster può essere gestito in vari modi, al posto di
`csi-driver-nfs` si potrebbe optare per l'uso di #link(
  "https://ceph.com",
)[CephFS], un filesystem distribuito che supporta nativamente la creazione di
volumi tipo #en[block storage] (utile per VM o per usare altri filesystem sullo
stesso hardware), #en[object storage] (compatibile con S3), e #en[file storage].
Ceph può essere integrato in questo sistema in vari modi:
- sfruttando il supporto nativo di ProxmoxVE, utile nel caso si abbia più
  macchine fisiche in #en[cluster] ProxmoxVE e si voglia utilizzare dischi
  separati da quello del OS, in questo caso Ceph può ospitare anche i dischi
  virtuali delle VM e Kubernetes può gestire voluim sul #en[cluster] esterno
  sfruttando #link(
    "https://github.com/ceph/ceph-csi",
  )[`ceph-csi`] configurato a mano o gestito tramite l'operatore #link(
    "https://rook.io/",
  )[`rook`].
- nel caso si abbia realizzato un #en[cluster bare metal] con dischi separati da
  quello del OS, Ceph può essere ingrato direttamente in Kubernetes utilizzando
  `rook` per gestire direttamente il cluster Ceph (interno).

Nel caso non si abbia a disposizione dischi da dedicare a Ceph o si voglia
utilizzare altri filesystem come ZFS, è possibile sfruttare direttamente lo
storage locale utilizzando #link("https://longhorn.io/")[LongHorn] o #link(
  "https://openebs.io/",
)[OpenEBS]

=== Servizi
Con il sistema sopra descritto `cert-manager` dipende da `LetsEncrypt` e da un
server DNS esterno alla rete locale per la generazione di certificati TLS. Se si
vuole rimuovere questa dipendenza è possibile creare una propria CA
#footnote[#en[Certificate Authority], "ente" che firma o emette certificati]
seguendo la #link("https://cert-manager.io/docs/configuration/ca/")[guida
  ufficiale] ed eventualmente configurando #link(
  "https://cert-manager.io/docs/trust/trust-manager/",
)[`trust-manager`] per semplificare l'impostazione della propria CA come
autentica all'interno del #en[cluster] (per evitare errori relativi a
certificati #en[self-signed] quando applicazioni dialogano)

= #en[Provisioning] di un'applicazione
Per il #en[provisioning] di un'applicazione sul #en[cluster] bisogna prima di
tutto "containarizzare" l'applicazione e aver chiaro in mente le dipendenze
esterne necessarie. In seguito bisogna creare un #en[namespace] per organizzare
meglio il #en[cluster] e isolare le applicazioni, al suo interno bisogna
definire quanti e quali #en[pod] o #en[container] devono esserci tramite uno o
più `Depoloyment`, `StatefulSets` e/o `DaemonSet`. Bisogna poi definire
eventuali `PersistentVolumeClaim` per fornire spazio di archiviazione
persistente ai pod, dei `Service` per i servizi esposti, e `ConfigMap` e
`Secret` per salvare credenziali e variabili che si vogliono poter modificare
senza alterare la definizione e specifiche dei #en[pod]. Infine bisogna definire
il come l'applicazione dev'essere raggiungibile dal esterno del cluster, per
farlo si può definire una risorsa di tipo `LoadBalancer`, utile nel caso non si
voglia avere #en[reverse proxy], bilanciamento di carico lato applicazione
(rimane in qualsiasi caso il bilanciamento tra nodi fornito da `kube-vip`), o si
voglia avere un IP dedicato alla singola applicazione. In alternativa si può
definire una risorsa `Ingress` (#en[legacy], semplice ma poco elastico),
`IngressRoute` (specifico di Traefik, elastico ma non standard), o sfruttare le
nuove API che permettono di definire un `Gateway` con le relative risorse
aggiuntive `TCPRoute`, `HTTPRoute`, etc. (API standard, non specifiche di un
singolo #en[proxy/load balancer], elastiche ma relativamente complesse). Infine
è possibile definire eventuali certificati TLS e record DNS, esplicitamente o
tramite annotazioni.

Per questo progetto è stato costruito un applicativo d'esempio, #link(
  "https://github.com/as3ii/k8s-testapp",
)[k8s-testapp], per tesare il #en[deployment] di un'applicazione utilizzando al
massimo tutte le funzionalità implementate. Quest'applicazione espone
un'interfaccia HTTP REST minimale, tramite la quale è possibile aggiungere,
leggere e togliere record da un #en[database] PostgreSQL. In questo caso, per
semplicità, il #en[backend web] è replicato 3 volte mentre il database è uno
solo (per non dover impostare un #en[cluster] Postgres), la gestione TLS/HTTPS e
il #en[load balancing] sono gestite da Traefik tramite la definizione di un
`Gateway` con due `HTTPRoute`, una senza TLS che redirige il traffico dalla
porta 80 alla 443 e l'altra per gestire effettivamente il traffico HTTPS.
Tramite annotazioni sul `Gateway` è stato indicato come dev'essere generato il
certificato TLS e il record DNS da creare sul server in LAN. Per ulteriori
informazioni fare riferimento al file #link(
  "https://github.com/as3ii/k8s-testapp/blob/master/README.md",
)[`README.md`] e ai vari file `yaml` nella #link(
  "https://github.com/as3ii/k8s-testapp/tree/master/k8s/simple",
)[cartella dedicata]

Un alternativa al uso di file "statici" con valori "#en[hard coded]" utilizzato
per definire l'ambiente per l'app di test, è possibile utilizzare #link(
  "https://kustomize.io/",
)[`kustomize`] per scrivere dei template e rendere il tutto più facile da
configurare.
