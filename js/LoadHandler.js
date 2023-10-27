class LoadHandler {
    constructor() {
        this.loadImages = {};
    }

    loadImage(src) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            img.onload = () => {
                this.loadImages[src] = img;
                resolve();
            };
            img.onerror = reject;
            img.src = src;
        });
    }

    async loadAllImages(imageFiles) {
        try {
            const loadPromises = imageFiles.map((file) => this.loadImage(file.src));
            await Promise.all(loadPromises);
            console.log("All images loaded successfully");
            return Promise.resolve();
        } catch (error) {
            console.error("Error loading images:", error);
            return Promise.reject(error);
        }
    }

    getImage (imageFile) {
        return this.loadImages[imageFile];
    }
}