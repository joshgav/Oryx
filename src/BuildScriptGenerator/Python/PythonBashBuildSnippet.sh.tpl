declare -r TS_FMT='[%T%z] '
declare -r REQS_NOT_FOUND_MSG='Could not find requirements.txt; Not running pip install'
echo "Python Version: $python"
cd "$SOURCE_DIR"

{{ if VirtualEnvironmentName | IsNotBlank }}

{{ if PackagesDirectory | IsNotBlank }}
if [ -d "{{ PackagesDirectory }}" ]
then
	rm -fr "{{ PackagesDirectory }}"
fi
{{ end }}

VIRTUALENVIRONMENTNAME={{ VirtualEnvironmentName }}
VIRTUALENVIRONMENTMODULE={{ VirtualEnvironmentModule }}
VIRTUALENVIRONMENTOPTIONS={{ VirtualEnvironmentParameters }}

echo "Python Virtual Environment: $VIRTUALENVIRONMENTNAME"

echo Creating virtual environment ...
$python -m $VIRTUALENVIRONMENTMODULE $VIRTUALENVIRONMENTNAME $VIRTUALENVIRONMENTOPTIONS

echo Activating virtual environment ...
source $VIRTUALENVIRONMENTNAME/bin/activate

if [ -e "requirements.txt" ]
then
	pip install --upgrade pip
	pip install --prefer-binary -r requirements.txt
else
	echo $REQS_NOT_FOUND_MSG
fi

# For virtual environment, we use the actual 'python' alias that as setup by the venv,
python_bin=python

{{ else }}

if [ -e "requirements.txt" ]
then
	echo Running pip install...

	$pip install --prefer-binary -r requirements.txt --target="{{ PackagesDirectory }}" --upgrade
	pipInstallExitCode=${PIPESTATUS[0]}

	if [[ $pipInstallExitCode != 0 ]]
	then
		exit $pipInstallExitCode
	fi
else
	echo $REQS_NOT_FOUND_MSG
fi

# We need to use the python binary selected by benv
python_bin=$python

# Detect the location of the site-packages to add the .pth file
# For the local site package, only major and minor versions are provided, so we fetch it again
SITE_PACKAGE_PYTHON_VERSION=$($python -c "import sys; print(str(sys.version_info.major) + '.' + str(sys.version_info.minor))")
SITE_PACKAGES_PATH=$HOME"/.local/lib/python"$SITE_PACKAGE_PYTHON_VERSION"/site-packages"
mkdir -p $SITE_PACKAGES_PATH
# To make sure the packages are available later, e.g. for collect static or post-build hooks, we add a .pth pointing to them
APP_PACKAGES_PATH=$(pwd)"/{{ PackagesDirectory }}"
echo $APP_PACKAGES_PATH > $SITE_PACKAGES_PATH"/oryx.pth"

{{ end }}

echo Done running pip install.


{{ if !DisableCollectStatic }}

if [ -e "$SOURCE_DIR/manage.py" ]
then
	if grep -iq "Django" "$SOURCE_DIR/requirements.txt"
	then
		echo
		echo Content in source directory is a Django app
		echo Running 'collectstatic' ...
		$python_bin manage.py collectstatic --noinput || EXIT_CODE=$? && true ; 
		echo "'collectstatic' exited with exit code $EXIT_CODE."
	fi
fi

{{ end }}
