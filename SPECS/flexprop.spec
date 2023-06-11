Name: flexprop
Version: 6.1.5
Release: 1%{?dist}
Summary: Flexprop GUI for Parallax Propeller development

License: MIT        
URL: https://github.com/drwonky/flexprop
Source: https://github.com/drwonky/flexprop.git
#URL: https://github.com/totalspectrum/flexprop
#Source: https://github.com/totalspectrum/flexprop.git

BuildRequires: gcc-c++ tk-devel texlive-latex pandoc libXScrnSaver-devel
Requires: bzip2-libs fontconfig freetype glib2 glibc graphite2 harfbuzz libbrotli libpng libX11 libXau libxcb libXext libXft libxml2 libXrender libXScrnSaver pcre tcl tk xz-libs zlib libgcc libstdc++

%description
FlexProp is a GUI for Parallax Propeller development. It is a cross-platform


%prep
#%{__rm} -rf %{name} || true
#%{__git} clone --recursive %{url}


%build
cd %{name}
%make_build build


%install
%{__mkdir_p} %{buildroot}%{_datadir}/%{name}
%{__mkdir_p} %{buildroot}%{_docdir}/%{name}
%{__install} -p -m 0644 License.txt %{buildroot}%{_docdir}/%{name}
%{__install} -p -m 0644 README.md %{buildroot}%{_docdir}/%{name}
%{__cp} -r %{name}/doc %{buildroot}%{_docdir}/%{name}/
%{__install} -p -m 0755 %{name}.bin %{buildroot}%{_bindir}/%{name}
%{__install} -p -m 0755 bin/* %{buildroot}%{_bindir}/
%{__cp} -r %{name}/include %{buildroot}%{_datadir}/%{name}/
%{__cp} -r %{name}/board %{buildroot}%{_datadir}/%{name}/
%{__cp} -r %{name}/samples %{buildroot}%{_datadir}/%{name}/
%{__cp} -r %{name}/src %{buildroot}%{_datadir}/%{name}/
%{__cp} -r tcp_library %{buildroot}%{_datadir}/%{name}/


%files
%license %{_docdir}/%{name}/License.txt
%doc %{_docdir}/%{name}/doc/
%{datadir}/%{name}/
%{_bindir}/%{name}


%changelog
* Sat Jun 03 2023 Perry Harrington <pedward@apsoft.com>
- Created spec file
