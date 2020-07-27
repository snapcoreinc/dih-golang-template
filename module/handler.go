package module

import (
	"fmt"
	"math/rand"
	"time"

	"github.com/oklog/ulid"
)

// Handle a serverless request
func Handle(req []byte) string {
	return fmt.Sprintf("[%s] Hello, Go. You said: %s", genULID(), string(req))
}

func genULID() string {
	t := time.Now()
	entropy := ulid.Monotonic(rand.New(rand.NewSource(t.UnixNano())), 0)
	return fmt.Sprint(ulid.MustNew(ulid.Timestamp(t), entropy))
}
