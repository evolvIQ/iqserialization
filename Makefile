FWK_NAME=IQSerialization.framework
DEBUG_FWK=Products/Debug/$(FWK_NAME)
RELEASE_FWK=Products/Release/$(FWK_NAME)

all: $(DEBUG_FWK) $(RELEASE_FWK)

release: $(RELEASE_FWK)

debug: $(DEBUG_FWK)

$(DEBUG_FWK): IQSerialization/*
	xcodebuild -configuration "Debug" -target "IQSerialization - Universal" -sdk iphoneos
	mkdir -p Products/Debug
	rm -rf $(DEBUG_FWK)
	cp -R build/Debug-universal/$(FWK_NAME) Products/Debug

$(RELEASE_FWK): IQSerialization/*
	xcodebuild -configuration "Release" -target "IQSerialization - Universal" -sdk iphoneos
	mkdir -p Products/Release
	rm -rf $(RELEASE_FWK)
	cp -R build/Release-universal/$(FWK_NAME) Products/Release

clean:
	rm -rf Products/Debug
	rm -rf Products/Release
	rm -rf build
