# 在 wsl2 中开发 flutter 应用

## 前言

因为换了新电脑之后把多数开发环境转移到了 wsl2（Debian）里，而一直想学学 flutter 开发，就想也在 wsl 里设置 flutter 的开发环境，折腾了几天，算是踩了不少坑。写一篇短文记录下折腾的过程吧，希望对后人（包括以后哪天因为任何原因要重装环境的我）有所帮助。

## Android SDK 安装

这一步倒是没啥问题，基本上可能遇到的问题都能在网上找到解决方案。

首先是安装 java，我参考了[这里](https://stackoverflow.com/questions/57031649/how-to-install-openjdk-8-jdk-on-debian-10-buster)

```console
wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | sudo apt-key add -
sudo add-apt-repository --yes https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/
sudo apt-get update && sudo apt-get install adoptopenjdk-8-hotspot
```

由于使用 flutter 所以 Android Studio 并不是必要的，我就只下载了 commandline-tools（在[这个页面](https://developer.android.com/studio)偏下方）放在一个记得住的路径。

```console
wget https://dl.google.com/android/repository/commandlinetools-linux-6858069_latest.zip
unzip  commandlinetools-linux-6858069_latest.zip -d cmdline-tools
rm commandlinetools-linux-6858069_latest.zip -f
mv cmdline-tools/{cmdline-,}tools
mkdir /usr/local/bin/AndroidSDK
sudo mv cmdline-tools /usr/local/bin/AndroidSDK/
```

之后用 tools/bin 里的 sdkmanager 安装必要的 platform-tools（最好选最新版的，因为要和 windows 里装的版本一致）build-tools，设置好环境变量，安装 gradle，就算是完成了。（可以参考[这一篇文章](https://itnext.io/flutter-with-wsl-2-69ba8fc7682f)的前半部分）

```console
cd /usr/local/bin/AndroidSDK/cmdline-tools/tools/bin
./sdkmanager --list
# 在列表里找到想要安装的工具
./sdkmanager --install "platform-tools" "platforms;android-28" "build-tools;28.0.3"
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install gradle 5.5.1
```

## flutter SDK 安装

### 安装

建议按照[这里](https://flutter.dev/docs/get-started/install/linux)的**手动安装**流程做，因为想在 wsl2 里运行 snapd 还是需要一番折腾的（没有 systemd）

在有关 Android Studio 和模拟器的环节直接跳过就好。

最后用 flutter config 设置 Android SDK 的路径。

```console
cd
wget https://storage.googleapis.com/flutter_infra/releases/stable/linux/flutter_linux_1.22.6-stable.tar.xz
tar xf flutter_linux_1.22.6-stable.tar.xz
mv flutter /usr/local/bin/AndroidSDK/
```

再找到 shell 配置（.bashrc .zshrc 等等），添加

```console
export ANDROID_HOME=/usr/local/bin/AndroidSDK/cmdline-tools/tools
export ANDROID_SDK_ROOT=/usr/local/bin/AndroidSDK
export PATH=$PATH:$ANDROID_HOME/bin
export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools
export PATH=$PATH:$ANDROID_SDK_ROOT/flutter/bin
```

重开个终端就能生效了。

### 代理设置

flutter 的代理设置读取的是环境变量 http_proxy 和 https_proxy，我在.zshrc 里设置了 wsl 启动时获取 windows_host 的 ip 地址设置相关环境变量（可以参考[这里](https://zinglix.xyz/2020/04/18/wsl2-proxy/)）所以没有问题。

flutter 编译过程中会用到 gradle，默认配置在 `~/.gradle/gradle.properties` 里，找到对应 `systemProp.http.proxyHost=` 和 `systemProp.https.proxyHost=` 的行数（我这里是 14 和 16），在.zshrc 里加入类似以下的代码即可：

```console
sed -i "14c systemProp.http.proxyHost=$windows_host" ~/.gradle/gradle.properties
sed -i "16c systemProp.https.proxyHost=$windows_host" ~/.gradle/gradle.properties
```

这样每次 wsl 启动对应代理地址都会更新。

### 如果我不想用代理呢？

参考官方给的[这一篇文档](https://flutter.dev/community/china)

### 检查问题

运行 `flutter doctor`看看有没有发现什么问题，通常会报 Android Studio 没有安装，忽略即可。

如果提示 NO_PROXY 没有设定，设置环境变量 `NO_PROXY=localhost,127.0.0.1` 即可。

如果提示找不到 Android SDK，执行

```console
flutter config --android-sdk /usr/local/bin/AndroidSDK
```

## windows 端环境（模拟器）

由于我们不能在 wsl 里跑安卓模拟器，所以需要从 wsl 里连接 windows 里运行的模拟器。

从[这里](https://developer.android.com/studio)下载 windows 的 commandline-tools，放到一个方便的路径，并把 tools/bin 添加到环境变量 PATH 里。

在 powershell 里用 sdkmanager 安装 platform-tools（记得匹配 wsl 里的版本）emulator 以及 system-image（我用的 api28，x86_64），再用 avdmanager 创建一个新的模拟器。

```posh
sdkmanager --list
sdkmanager --install "build-tools;28.0.3" "emulator" "platform-tools" "platforms;android-9" "system-images;android-28;google_apis;x86_64"
# 创建一个名为Android28的模拟器
avdmanager create avd --name Android28 --package "system-images;android-28;google_apis;x86_64"
emulator -avd Android28 -skin 1080x1920
```

此时虚拟机应该能启动了。
保持这个 powershell 终端不要关，再开一个 powershell 终端，执行

```posh
adb -a -P 5037 nodaemon server
```

此时回到 wsl 终端，在.zshrc（.bashrc 等等）里加入

```console
export windows_host=`cat /etc/resolv.conf|grep nameserver|awk '{print $2}'`
export ADB_SERVER_SOCKET=tcp:$windows_host:5037
```

然后重开个 wsl 终端， `adb devices` 应该能看到模拟器了。

美中不足的就是每次用到模拟器都要这样开两个终端。

## 让 flutter 能访问到模拟器

我本来也以为这样就完事了，于是尝试创建一个项目。

```console
flutter create helloworld
cd helloworld
flutter run
```

结果是模拟器打开了一个白屏应用，终端提示

> Connecting to the VM Service is taking longer than expected...  
> Still attempting to connect to the VM Service...  
> If you do NOT see the Flutter application running, it might have crashed. The device logs (e.g. from adb or XCode) might have more details.  
> If you do see the Flutter application running on the device, try re-running with --host-vmservice-port to use a specific port known to be available.

猜测原因是 flutter 尝试用 127.0.0.1 连接到模拟器来实现 hot reload，但 wsl2 里 127.0.0.1 并不对应 windows_host，而这个地址似乎没有办法通过 flutter 设置或者参数传入，这里需要一个工具当作桥梁。

```console
sudo apt update
sudo apt install socat
```

在.zshrc（.bashrc 等等）里加入

```console
# 改成你想要的端口
SOCAT_PORT=1145
stop_socat(){
        start-stop-daemon \
                         --oknodo --quiet --stop \
                         --pidfile /tmp/socat-$SOCAT_PORT.pid \
                         --exec /usr/bin/socat
        rm -f /tmp/socat-$SOCAT_PORT.pid
}
start_socat(){
        if [ -f "/tmp/socat-$SOCAT_PORT.pid" ]; then
                stop_socat
        fi
        start-stop-daemon \
                         --oknodo --quiet --start \
                         --pidfile /tmp/socat-$SOCAT_PORT.pid \
                         --background --make-pidfile \
                         --exec /usr/bin/socat TCP-LISTEN:$SOCAT_PORT,reuseaddr,fork TCP:$windows_host:$SOCAT_PORT < /dev/null
}
start_socat
```

重开一个终端，此时 socat 应该已经在后台准备好了。

```console
cd helloworld
# 记得改成你选用的端口
flutter run --host-vmservice-port 1145
```

好耶！成功了！

## Vscode 设置

Vscode 里理论上只需要安装 flutter 官方的拓展程序就可以了，不过我们需要传入--host-vmservice-port 参数，所以在安装完拓展程序后到设置里修改以下设置：

- Flutter Attach Additional Args
  - --host-vmservice-port
  - 1145
- Flutter Run Additional Args
  - --host-vmservice-port
  - 1145
- Flutter Test Additional Args
  - --host-vmservice-port
  - 1145

没错，参数名和数值要各占一行，这里卡了我很久。

此时再运行就大功告成了。
