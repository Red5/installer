Summary: Red5 Server
Name: red5
Version: @VERSION@
Release: 1%{?dist}
Source0: %{name}-server-%{version}-RELEASE-server.tar.gz
Source2: red5.init
License: Apache Software License 2.0
URL: http://www.red5.org/
Group: Applications/Networking
BuildRoot: %{_builddir}/%{name}-%{version}-%{release}-root
Requires: chkconfig
Requires: java

%define red5_home   /var/lib/red5

%description
The Red5 open source Flash server allows you to record and stream video to the Flash Player.

%prep
%setup -q -n red5-server-%{version}-RELEASE

%build
rm -f *.bat

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{red5_home}
cp -r ./* $RPM_BUILD_ROOT%{red5_home}
install -m 0755 -d $RPM_BUILD_ROOT%{red5_home}/plugins
install -m 0755 plugins/* $RPM_BUILD_ROOT%{red5_home}/plugins
install -d $RPM_BUILD_ROOT/etc/rc.d/init.d
install -m 0755 %{SOURCE2} $RPM_BUILD_ROOT/etc/rc.d/init.d/red5
install -m 0755 -d $RPM_BUILD_ROOT/%{red5_home}/log

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%attr(0755,root,root) %dir %{red5_home}
%attr(0644,root,root) %{red5_home}/*.jar
%attr(0755,root,root) %{red5_home}/*.sh

%attr(0755,root,root) %dir %{red5_home}/lib
%attr(0644,root,root) %{red5_home}/lib/*

%attr(0755,root,root) %dir %{red5_home}/webapps
%attr(0644,root,root) %{red5_home}/webapps/*

%attr(0755,root,root) %dir %{red5_home}/plugins
%attr(0644,root,root) %{red5_home}/plugins/*

%attr(0755,root,root) %dir %{red5_home}/conf
%config %{red5_home}/conf/*

%attr(0755,root,root) %dir %{red5_home}/log

%attr(0755,root,root) /etc/rc.d/init.d/red5
%doc license.txt

%ghost %{red5_home}/license.txt

%post
/sbin/chkconfig --add red5

%postun
/sbin/service red5 restart > /dev/null 2>&1 || :

%preun
if [ "$1" = 0 ]; then
    /sbin/service/red5 stop > /dev/null 2>&1 || :
    /sbin/chkconfig --del red5
fi

%changelog
* Wed Dec 10 2014 Tetsuya Morimoto <tetsuya.morimoto at gmail.com> 1.0.3-1%{?dist}
- update packaging for Red5 server 1.0.3

* Wed Dec 26 2012 Tetsuya Morimoto <tetsuya.morimoto at gmail.com> 1.0.0-1%{?dist}
- first packaging for Red5 1.0 Final
