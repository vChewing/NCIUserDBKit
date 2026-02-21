.PHONY: all

all:
	dotnet clean && dotnet restore && dotnet build --no-restore && dotnet test --no-build

.PHONY: format pack

format:
	dotnet format

pack:
	dotnet build NCIUserDBKit/NCIUserDBKit.csproj --configuration Release
	dotnet pack NCIUserDBKit/NCIUserDBKit.csproj --configuration Release --no-build --output ./nupkg
