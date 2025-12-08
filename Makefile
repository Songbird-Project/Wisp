build:
	go -C src vet
	go -C src build
	mv src/wisp .

clean:
	rm wisp
