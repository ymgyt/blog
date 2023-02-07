+++
title = "🗼 Kubernetes Meetup Tokyo #23にいってきました"
slug = "kubernetes-meetup-tokyo-23"
date = "2019-09-27"
draft = true
[taxonomies]
tags = ["cncf", "event"]
+++

2019年9月27日に開催された[Kubernetes Meetup Tokyo #23](https://k8sjp.connpass.com/event/145942/)にブログ枠で参加させていただいたので、その模様について書いていきます。


## 会場

会場は渋谷ストリームの隣に誕生した渋谷スクランブルスクエアです。ビルの正式オープンが11月からとのことで絶賛内装工事中でした。
渋谷駅直結でとても便利な立地です。スポンサーは**CyberAgent**社です。

{{ figure(caption="Session後の懇談会の様子", images=[
  "images/site_1.jpeg",
  "images/site_2.jpeg",
  "images/site_3.jpeg",
], width="32%") }}


## Session

### ゼロから始めるKubernetes Controller

[技術書典7](https://techbookfest.org/event/tbf07)で買わせていただいた、[実践入門Kubernetes カスタムコントローラへの道](https://go-vargo.booth.pm/items/1566979)の著者であられる[バルゴさん](https://twitter.com/go_vargo)によるKubernetes Controllerについての発表。


{{ figure(images=[
  "images/load_to_custom_controller.jpeg",
])}}

<iframe class="speakerdeck-iframe" frameborder="0" src="https://speakerdeck.com/player/173fdf8b50f445ba895b82fb6650825c" title="ゼロから始めるKubernetes Controller / Under the Kubernetes  Controller" allowfullscreen="true" mozallowfullscreen="true" webkitallowfullscreen="true" style="border: 0px; background: padding-box padding-box rgba(0, 0, 0, 0.1); margin: 0px; padding: 0px; border-radius: 6px; box-shadow: rgba(0, 0, 0, 0.2) 0px 5px 40px; width: 100%; height: auto; aspect-ratio: 560 / 420;" data-ratio="1.3333333333333333"></iframe>


Controllerの概要から内部の実装についてまで説明されている100P超えの力作スライドです。
ReplicaSetをapplyしてからデリバリされるまでの処理を該当ソースへの参照箇所まで添えて説明してくれており開始10分でこれてよかったと思えました。


### kubebuilder/controller-runtime入門 with v2 updates


[kfyharukzさん](https://github.com/kfyharukz)によるkubebuilder v2の紹介/デモ。

kubernetesのAPIを拡張するためのSDK [kubebuilder](https://github.com/kubernetes-sigs/kubebuilder)についての発表です。

<iframe src="//www.slideshare.net/slideshow/embed_code/key/fl9arNMEK2OZya" width="595" height="485" frameborder="0" marginwidth="0" marginheight="0" scrolling="no" style="border:1px solid #CCC; border-width:1px; margin-bottom:5px; max-width: 100%;" allowfullscreen> </iframe> <div style="margin-bottom:5px"> <strong> <a href="//www.slideshare.net/KazuhitoMatsuda1/kubernetes-meetup-tokyo-23-kubebuilderv2" title="Kubernetes Meetup Tokyo #23 kubebuilder-v2" target="_blank">Kubernetes Meetup Tokyo #23 kubebuilder-v2</a> </strong> from <strong><a href="//www.slideshare.net/KazuhitoMatsuda1" target="_blank">Kazuhito Matsuda</a></strong> </div>


Kubernetesのbuiltin Resouceの理解もまだあやしい自分にとっては発展的な内容でした。CKA合格できたらCustom Resourceにも挑戦したいです。


## Kubernetes 1.16: SIG-API Machineryの変更内容

Introduction of Operator Frameworkが行われる予定でしたが、発表者の方が体調不良とのことで内容が変更になりました。


[Ladicleさん](https://twitter.com/Ladicle)による[Kubernetes 1.16: SIG-API Machineryの変更内容](https://qiita.com/Ladicle/items/f192d266b80e873eb0a8)
そもそもSIGという単語がわかっていませんでした。調べてみたところKubernetes Projectの開発単位という感じでしょうか。
興味があるSIGから追いかけてみるととっかかりとしてはよいというアドバイスもいただきました。

* [sig-list](https://github.com/kubernetes/community/blob/master/sig-list.md)

[zlab社](https://qiita.com/organizations/zlab)がQiitaでKubernetesやGo関連で参考になる記事をたくさんあげてくれているのでフォローしていこうと思いました。

* [zlab](https://qiita.com/organizations/zlab)

## Kubernetes 1.16: SIG-CLI の変更内容

同じく[zlab社](https://qiita.com/organizations/zlab)の[すぱぶらさん](https://twitter.com/superbrothers)による[Kubernetes 1.16: SIG-CLI の変更内容](https://qiita.com/superbrothers/items/e78a8a04347e57900fd9)です。

kubectlの実践的な解説で自分が打ったことがないコマンドやオプションばかりでした。  
`kubectl debug` は利用できたらとても便利そうなので待ち遠しいです。

## LT

### ClusterAPI v1alpha1 → v1alpha2 

[r_takaishiさん](https://twitter.com/r_takaishi)によるClusterAPIについて。
発表資料のリンクが見つけられず。
ClusterAPIについてはまったくわかっておらず。そもそもKubernetesってCluster(特にcontroll plane)は作成されている前提だと考えていたので気になるところです。
技術書典7では買えていなかった[はじめるCluster API](https://techiemedia.booth.pm/items/1579677)読んで出直します。

{{ figure(images=["images/cluster_api_book.jpeg"]) }}


### 自動化はshell-operator とともに。 

[nwiizoさん](https://twitter.com/nwiizo)さんによるshell(bash)とkubernetesについて。
そもそも、operatorについてのわかっていないので、なんかbashでもkubernetesの処理にはさめるんだなくらいの理解しかできませんでした。
ここは議論のあるところだと思いますが、自分は以下の点からあまりbashを本番関連の処理に組み込みたくないと考えているのですがどうなんでしょうか。

* network処理には必ずtimeout設定したい
* error handling
* logging(structured, leveling,...)
* signal handling(gracefully shutdown, resource cleanup等)
* test書きたい
* 依存を明示

(bashでできないことはないと思うのですが上記のことやろうとすると肥大化するかscriptの手軽さが結局失われる)


### 自作 Controller による Secret の配布と収集 - unblee

[unbleeさん](https://twitter.com/unblee)による[自作 Controller による Secret の配布と収集](https://speakerdeck.com/unblee/distributing-and-collecting-secrets-with-self-made-controller)

wantedly社でのKubernetes運用上の課題をControllerを作成して解決されたお話でした。  
1-MicroService 1-Namespaceで運用されているそうです、実運用されている方々のNamespaceの切り方についてはもっとお話を伺ってみたいと思いました。

## 懇談会

SessionとLTの間に30分程度の懇談会の時間が設けられています。(飲食物の提供は**CyberAgent**社)
たまたま技術書典7で買って、当日も読んでいたカスタムコントローラへの道の著者の[バルゴさん](https://twitter.com/go_vargo)が発表されていたので、本買いましたとご挨拶させていただきました。またCKA、CKADをお持ちとのことで、[CKAのアドバイス](https://qiita.com/go_vargo/items/3644c3a44734e2c155f4)も聞けました。


[Ladicleさん](https://twitter.com/Ladicle)の発表の際に用いられていたQiitaのiconどこかでみたことあるなー思っていたのですが、[Software Design 2017年9月号](https://gihyo.jp/dp/ebook/2017/978-4-7741-8845-4)の特集 Web技術【超】入門いま一度振り返るWebのしくみと開発方法で[web serverの実装](https://github.com/Ladicle/http-handson)をgoでやられている方であることを思い出しました。  
`go-bindata`で静的アセットファイルをgoのバイナリーに組み込むやり方をここではじめて知りました。


## 次回

次回は10月24日で、Kubernetes上で動かすアプリケーション開発のデバックとテストについてだそうです。
こちらも楽しみですね。

## まとめ

Kubernetes Meetup Tokyoには初参加で、自分のKubernetesについての理解が、GKEにslack botをdeployしてみる程度([会社のブログで記事](http://blog.howtelevision.co.jp/entry/2019/04/30/193747)にしました。)
でしたがとても勉強になり参加してよかったです。


## せっかくなのでゼロから始めるKubernetes Controllerをおってみる


[ゼロから始めるKubernetes Controller](https://speakerdeck.com/govargo/under-the-kubernetes-controller-36f9b71b-9781-4846-9625-23c31da93014)で、ReplicaSetをapplyした際のControllerの挙動が該当コードのリンクつきで解説されているので、追えるところまでおってみました。[kubernetesのversionは1.16です](https://github.com/kubernetes/kubernetes/tree/release-1.16)


### `kubectl apply`

{{ figure(images=["images/controller_1.jpeg"],
  href="https://speakerdeck.com/govargo/under-the-kubernetes-controller-36f9b71b-9781-4846-9625-23c31da93014?slide=19"
)}}


`kubectl`でReplicaSetをapplyして、api-serverで処理されている前提です。


### `ReplicaSet Controller`の起動

slideでは、`ReplicaSetController`が`ReplicaSet`が生成されたことを検知したところから解説されていますが、起動処理を簡単におってみました。

`ReplicaSetController`自体は、`kube-controller-manager` binaryに含まれているので、起動処理は`kube-controller-manager`コマンドから始まります。

```go
// Run runs the KubeControllerManagerOptions.  This should never exit.
func Run(c *config.CompletedConfig, stopCh <-chan struct{}) error {
  // ...
  if err := StartControllers(controllerContext, saTokenControllerInitFunc, NewControllerInitializers(controllerContext.LoopMode), unsecuredMux); err != nil {
			klog.Fatalf("error starting controllers: %v", err)
	}
  // ...
}
```
[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/cmd/kube-controller-manager/app/controllermanager.go#L234](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/cmd/kube-controller-manager/app/controllermanager.go#L234)

```go
func NewControllerInitializers(loopMode ControllerLoopMode) map[string]InitFunc {
  controllers := map[string]InitFunc{}
  // ...
  controllers["replicaset"] = startReplicaSetController
  // ...
  return controllers
}
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/cmd/kube-controller-manager/app/controllermanager.go#L386](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/cmd/kube-controller-manager/app/controllermanager.go#L386)




```go
func StartControllers(ctx ControllerContext, startSATokenController InitFunc, controllers map[string]InitFunc, unsecuredMux *mux.PathRecorderMux) error {
   // ...
  for controllerName, initFn := range controllers {
		// ...
		debugHandler, started, err := initFn(ctx)
		// ...
  }

  return nil
```
[https://github.com/kubernetes/kubernetes/blob/release-1.16//cmd/kube-controller-manager/app/controllermanager.go#L498:6:title](https://github.com/kubernetes/kubernetes/blob/release-1.16//cmd/kube-controller-manager/app/controllermanager.go#L498)

各controllerの起動処理を実行しているようです。
肝心の`ReplicaSetController`の起動処理をみてみます。

```go
func startReplicaSetController(ctx ControllerContext) (http.Handler, bool, error) {
	// ...
	go replicaset.NewReplicaSetController(
		ctx.InformerFactory.Apps().V1().ReplicaSets(),
		ctx.InformerFactory.Core().V1().Pods(),
		ctx.ClientBuilder.ClientOrDie("replicaset-controller"),
		replicaset.BurstReplicas,
	).Run(int(ctx.ComponentConfig.ReplicaSetController.ConcurrentRSSyncs), ctx.Stop)
	return nil, true, nil
}
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/cmd/kube-controller-manager/app/apps.go#L69](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/cmd/kube-controller-manager/app/apps.go#L69)

`ReplicaSetController`の生成と起動処理を別goroutineで実行しているようです。


```go
func (rsc *ReplicaSetController) Run(workers int, stopCh <-chan struct{}) {
	// ...
	for i := 0; i < workers; i++ {
		go wait.Until(rsc.worker, time.Second, stopCh)
	}

	<-stopCh
}
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/controller/replicaset/replica_set.go#L177:34](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/controller/replicaset/replica_set.go#L177)

指定された数のworkerを起動して、`stopCh`でblockしています。


```go
func (rsc *ReplicaSetController) worker() {
	for rsc.processNextWorkItem() {
	}
}

func (rsc *ReplicaSetController) processNextWorkItem() bool {
	key, quit := rsc.queue.Get()
	if quit {
		return false
	}
	defer rsc.queue.Done(key)

	err := rsc.syncHandler(key.(string))
	if err == nil {
		rsc.queue.Forget(key)
		return true
	}

	utilruntime.HandleError(fmt.Errorf("Sync %q failed with %v", key, err))
	rsc.queue.AddRateLimited(key)

	return true
}
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/controller/replicaset/replica_set.go#L432:34](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/controller/replicaset/replica_set.go#L432)

肝心のworkerはqueueからtaskを取得して、`ReplicaSetController.syncHandler()`処理を呼び出しています。
このqueueまわりもslideの後半で解説されていましたが、概要としてはapi-serverからcontrollerが関心のあるEventに絞って取得していると理解しています。

```go
func NewBaseController(rsInformer appsinformers.ReplicaSetInformer, podInformer coreinformers.PodInformer, kubeClient clientset.Interface, burstReplicas int,
	gvk schema.GroupVersionKind, metricOwnerName, queueName string, podControl controller.PodControlInterface) *ReplicaSetController {
    //...
    rsc.syncHandler = rsc.syncReplicaSet

	return rsc
}
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/controller/replicaset/replica_set.go#L163](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/controller/replicaset/replica_set.go#L163)

`ReplicaSetController.syncHandler`には`syncReplicaSet`が生成処理時にセットされています。


```go
// syncReplicaSet will sync the ReplicaSet with the given key if it has had its expectations fulfilled,
// meaning it did not expect to see any more of its pods created or deleted. This function is not meant to be
// invoked concurrently with the same key.
func (rsc *ReplicaSetController) syncReplicaSet(key string) error {
	// ...
	namespace, name, err := cache.SplitMetaNamespaceKey(key)
	// ...
	rs, err := rsc.rsLister.ReplicaSets(namespace).Get(name)
	// ...
	selector, err := metav1.LabelSelectorAsSelector(rs.Spec.Selector)
	// ...
	allPods, err := rsc.podLister.Pods(rs.Namespace).List(labels.Everything())
	// ...

	// Ignore inactive pods.
	filteredPods := controller.FilterActivePods(allPods)

	// NOTE: filteredPods are pointing to objects from cache - if you need to
	// modify them, you need to copy it first.
	filteredPods, err = rsc.claimPods(rs, selector, filteredPods)
	// ...

	var manageReplicasErr error
	if rsNeedsSync && rs.DeletionTimestamp == nil {
		manageReplicasErr = rsc.manageReplicas(filteredPods, rs)
	}
    // ...
```

概要としては、処理対象の`ReplicaSet`とfilterlingした`Pod`を取得して、`ReplicaSetController.manageReplicas()`を呼んでいます。
これでようやくslideの最初の処理のたどり着きました。



### `ReplicaSetController.manageReplicas()`

{{ figure(images=["images/controller_2.jpeg"], href="https://speakerdeck.com/govargo/under-the-kubernetes-controller-36f9b71b-9781-4846-9625-23c31da93014?slide=20")}}

```go
// manageReplicas checks and updates replicas for the given ReplicaSet.
// Does NOT modify <filteredPods>.
// It will requeue the replica set in case of an error while creating/deleting pods.
func (rsc *ReplicaSetController) manageReplicas(filteredPods []*v1.Pod, rs *apps.ReplicaSet) error {
	diff := len(filteredPods) - int(*(rs.Spec.Replicas))
	rsKey, err := controller.KeyFunc(rs)
	// ...
	if diff < 0 {
		diff *= -1
		// ...
		successfulCreations, err := slowStartBatch(diff, controller.SlowStartInitialBatchSize, func() error {
			err := rsc.podControl.CreatePodsWithControllerRef(rs.Namespace, &rs.Spec.Template, rs, metav1.NewControllerRef(rs, rsc.GroupVersionKind))
			if err != nil && errors.IsTimeout(err) {
				// ...
				return nil
			}
			return err
		})
		// ...

		return err
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/controller/replicaset/replica_set.go#L459:34](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/controller/replicaset/replica_set.go#L459)


```go
func slowStartBatch(count int, initialBatchSize int, fn func() error) (int, error) {
	remaining := count
	successes := 0
	for batchSize := integer.IntMin(remaining, initialBatchSize); batchSize > 0; batchSize = integer.IntMin(2*batchSize, remaining) {
		errCh := make(chan error, batchSize)
		var wg sync.WaitGroup
		wg.Add(batchSize)
		for i := 0; i < batchSize; i++ {
			go func() {
				defer wg.Done()
				if err := fn(); err != nil {
					errCh <- err
				}
			}()
		}
		wg.Wait()
		curSuccesses := batchSize - len(errCh)
		successes += curSuccesses
		if len(errCh) > 0 {
			return successes, <-errCh
		}
		remaining -= batchSize
	}
	return successes, nil
}
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/controller/replicaset/replica_set.go#L658](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/controller/replicaset/replica_set.go#L658)

`Pod`と`ReplicaSet`のreplica数の差分をとって、`Pod`の作成処理を実行していますね。
`slowStartBatch()`は作成処理を並列で走らせるhelper関数のようです。
段階的に一度に起動するgoroutineの数を増やしていく処理の書き方として非常に参考になります。(`IntMin()`のような処理はstd libで欲しいと思ってしまう)
`ReplicaSetController.podControl`はinterfaceで、実際の`Pod`作成処理は`ReadPodControl`が実装しています。

```go
func (r RealPodControl) CreatePodsWithControllerRef(namespace string, template *v1.PodTemplateSpec, controllerObject runtime.Object, controllerRef *metav1.OwnerReference) error {
	if err := validateControllerRef(controllerRef); err != nil {
		return err
	}
	return r.createPods("", namespace, template, controllerObject, controllerRef)
}
```
[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/controller/controller_utils.go#L523](https://speakerdeck.com/govargo/under-the-kubernetes-controller-36f9b71b-9781-4846-9625-23c31da93014?slide=19)


```go
func (r RealPodControl) createPods(nodeName, namespace string, template *v1.PodTemplateSpec, object runtime.Object, controllerRef *metav1.OwnerReference) error {
	pod, err := GetPodFromTemplate(template, object, controllerRef)
	// ...
	if len(nodeName) != 0 {
		pod.Spec.NodeName = nodeName
	}
	// ...
	newPod, err := r.KubeClient.CoreV1().Pods(namespace).Create(pod)
	if err != nil {
		r.Recorder.Eventf(object, v1.EventTypeWarning, FailedCreatePodReason, "Error creating: %v", err)
		return err
	}
	// ...
	return nil
}
```
[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/controller/controller_utils.go#L567](https://speakerdeck.com/govargo/under-the-kubernetes-controller-36f9b71b-9781-4846-9625-23c31da93014?slide=19)


確かにslideのとおり、`r.createPods("", namespace, template, controllerObject, controllerRef)` として`nodeName`が空の`Pod`を生成しているのがわかります。


### Schedulerがenqueue

{{ figure(images=["images/controller_3.jpeg"], href="https://speakerdeck.com/govargo/under-the-kubernetes-controller-36f9b71b-9781-4846-9625-23c31da93014?slide=21")}}

```go
func AddAllEventHandlers(...) {
    // ...
	podInformer.Informer().AddEventHandler(
		cache.FilteringResourceEventHandler{
			FilterFunc: func(obj interface{}) bool {
				switch t := obj.(type) {
				case *v1.Pod:
					return !assignedPod(t) && responsibleForPod(t, schedulerName)
				case cache.DeletedFinalStateUnknown:
					if pod, ok := t.Obj.(*v1.Pod); ok {
						return !assignedPod(pod) && responsibleForPod(pod, schedulerName)
					}
					utilruntime.HandleError(fmt.Errorf("unable to convert object %T to *v1.Pod in %T", obj, sched))
					return false
				default:
					utilruntime.HandleError(fmt.Errorf("unable to handle object in %T: %T", sched, obj))
					return false
				}
			},
			Handler: cache.ResourceEventHandlerFuncs{
				AddFunc:    sched.addPodToSchedulingQueue,
				UpdateFunc: sched.updatePodInSchedulingQueue,
				DeleteFunc: sched.deletePodFromSchedulingQueue,
			},
		},
	)
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/scheduler/eventhandlers.go#L418](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/scheduler/eventhandlers.go#L418)


```go
func assignedPod(pod *v1.Pod) bool {
	return len(pod.Spec.NodeName) != 0
}
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/scheduler/eventhandlers.go#L323](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/scheduler/eventhandlers.go#L418)


`Scheduler`が`podInformer`にevent handlerを登録する際に、podがassigne(`NodeName`が設定されている)されていないことを条件とするfilterを設定していることがわかります。


### kubeletはskip

{{ figure(images=["images/controller_4.jpeg"], href="https://speakerdeck.com/govargo/under-the-kubernetes-controller-36f9b71b-9781-4846-9625-23c31da93014?slide=22") }}

```go

// NewSourceApiserver creates a config source that watches and pulls from the apiserver.
func NewSourceApiserver(c clientset.Interface, nodeName types.NodeName, updates chan<- interface{}) {
	lw := cache.NewListWatchFromClient(c.CoreV1().RESTClient(), "pods", metav1.NamespaceAll, fields.OneTermEqualSelector(api.PodHostField, string(nodeName)))
	newSourceApiserverFromLW(lw, updates)
}
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/kubelet/config/apiserver.go#L32](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/kubelet/config/apiserver.go#L32)

`kubelet`のapi serverへのclient生成処理時に、`Pod`のHost名が(おそらく)自身のnode名と一致するFilterを設定しているようです。


### Schedulerがnode nameを設定

{{ figure(images=["images/controller_5.jpeg"], href="https://speakerdeck.com/govargo/under-the-kubernetes-controller-36f9b71b-9781-4846-9625-23c31da93014?slide=23")}}


```go
func (sched *Scheduler) scheduleOne() {
	// ...
	pod := sched.NextPod()
	// ...
	scheduleResult, err := sched.schedule(pod, pluginContext)
	// ...
	assumedPod := pod.DeepCopy()
	// ...

	// assume modifies `assumedPod` by setting NodeName=scheduleResult.SuggestedHost
	err = sched.assume(assumedPod, scheduleResult.SuggestedHost)
	// ...
}

```
[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/scheduler/scheduler.go#L516](white-space:nowrap;
overflow:scroll;)


```go
func (sched *Scheduler) assume(assumed *v1.Pod, host string) error {
    // ...
	assumed.Spec.NodeName = host
    // ...
	return nil
}
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/scheduler/scheduler.go#L447](white-space:nowrap;
overflow:scroll;)


Scheduling処理自体は一大Topicですが、流れとしては、なんらかの方法でNode名を選出して、`Pod`のnode名に指定していることがわかります。

### `kubelet`がコンテナを起動

{{ figure(images=["images/controller_6.jpeg"], href="https://speakerdeck.com/govargo/under-the-kubernetes-controller-36f9b71b-9781-4846-9625-23c31da93014?slide=24")}}

```go
func (m *kubeGenericRuntimeManager) SyncPod(pod *v1.Pod, podStatus *kubecontainer.PodStatus, pullSecrets []v1.Secret, backOff *flowcontrol.Backoff) (result kubecontainer.PodSyncResult) {
 	// ...
	// Step 6: start the init container.
	if container := podContainerChanges.NextInitContainerToStart; container != nil {
		// Start the next init container.
		if err := start("init container", container); err != nil {
			return
		}

		// Successfully started the container; clear the entry in the failure
		klog.V(4).Infof("Completed init container %q for pod %q", container.Name, format.Pod(pod))
	}
    // ...
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/kubelet/kuberuntime/kuberuntime_manager.go#L803](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/kubelet/kuberuntime/kuberuntime_manager.go#L803)

`kubelet`の処理はまったく追えていないのですが、コンテナを起動しているような処理を実行しています。


### `kubelet`が`Pod`のstatusを更新


[https://speakerd.s3.amazonaws.com/presentations/173fdf8b50f445ba895b82fb6650825c/preview_slide_24.jpg?13730934:image=https://speakerd.s3.amazonaws.com/presentations/173fdf8b50f445ba895b82fb6650825c/preview_slide_24.jpg?13730934](https://speakerd.s3.amazonaws.com/presentations/173fdf8b50f445ba895b82fb6650825c/preview_slide_24.jpg?13730934:image=https://speakerd.s3.amazonaws.com/presentations/173fdf8b50f445ba895b82fb6650825c/preview_slide_24.jpg?13730934)

```go
func (kl *Kubelet) syncPod(o syncPodOptions) error {
	// pull out the required options
	pod := o.pod
	mirrorPod := o.mirrorPod
	podStatus := o.podStatus
	updateType := o.updateType

	// ...

	// Generate final API pod status with pod and status manager status
	apiPodStatus := kl.generateAPIPodStatus(pod, podStatus)
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/kubelet/kubelet.go#L1481](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/kubelet/kubelet.go#L1481)


### `Pod`のTerminating

{{ figure(images=["images/controller_7.jpeg"], href="https://speakerdeck.com/govargo/under-the-kubernetes-controller-36f9b71b-9781-4846-9625-23c31da93014?slide=26")}}


```go
// dispatchWork starts the asynchronous sync of the pod in a pod worker.
// If the pod is terminated, dispatchWork
func (kl *Kubelet) dispatchWork(pod *v1.Pod, syncType kubetypes.SyncPodType, mirrorPod *v1.Pod, start time.Time) {
	if kl.podIsTerminated(pod) {
		if pod.DeletionTimestamp != nil {
			// If the pod is in a terminated state, there is no pod worker to
			// handle the work item. Check if the DeletionTimestamp has been
			// set, and force a status update to trigger a pod deletion request
			// to the apiserver.
			kl.statusManager.TerminatePod(pod)
		}
		return
	}
    // ...
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/kubelet/kubelet.go#L1999](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/kubelet/kubelet.go#L1999)


### `ReplicaSetController`が`Pod`を削除

{{ figure(images=["images/controller_8.jpeg"], href="https://speakerdeck.com/govargo/under-the-kubernetes-controller-36f9b71b-9781-4846-9625-23c31da93014?slide=28")}}


```go
func (rsc *ReplicaSetController) manageReplicas(filteredPods []*v1.Pod, rs *apps.ReplicaSet) error {
	diff := len(filteredPods) - int(*(rs.Spec.Replicas))
	rsKey, err := controller.KeyFunc(rs)
	// ...
	}
	if diff < 0 {
		// ...
	} else if diff > 0 {
		// ...
		// Choose which Pods to delete, preferring those in earlier phases of startup.
		podsToDelete := getPodsToDelete(filteredPods, diff)
		// ...
		errCh := make(chan error, diff)
		var wg sync.WaitGroup
		wg.Add(diff)
		for _, pod := range podsToDelete {
			go func(targetPod *v1.Pod) {
				defer wg.Done()
				if err := rsc.podControl.DeletePod(rs.Namespace, targetPod.Name, rs); err != nil {
					// ...
					errCh <- err
				}
			}(pod)
		}
		wg.Wait()

		select {
		case err := <-errCh:
			// all errors have been reported before and they're likely to be the same, so we'll only return the first one we hit.
			if err != nil {
				return err
			}
		default:
		}
	}

	return nil
}
```

[https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/controller/replicaset/replica_set.go#L459](https://github.com/kubernetes/kubernetes/blob/2f76f5e63872a40ac08056289a6c52b4f6250154/pkg/controller/replicaset/replica_set.go#L459)

ここで再び、`ReplicaSetController.manageReplicas()`に戻ってきました。今度は、specよりも実際の`Pod`が多いので、削除処理が走るようです。削除処理はシンプルに削除する数だけgoroutineを起動するようです。


### Reconcile

{{ figure(images=["images/controller_9.jpeg"], href="https://speakerd.s3.amazonaws.com/presentations/173fdf8b50f445ba895b82fb6650825c/preview_slide_29.jpg?13730939:image=https://speakerd.s3.amazonaws.com/presentations/173fdf8b50f445ba895b82fb6650825c/preview_slide_29.jpg?13730939") }}

ここまで、非常に簡単にですがslideにそって、`ReplicaSetController`を中心に該当コードを追いかけてみました。
kubernetesのcodeを初めて読んだのですが、各componentの実装がだいたいどのあたりあるのかを知るためのとっかかりとして非常に参考になりました。slideの後半では、`Informer`や`WorkQueue`についても解説されているので、是非そちらも追いかけてみようと思います。


