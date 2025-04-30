package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/jamesmcdonald/diceroller/pkg/dice"
)

func main() {
	if len(os.Args) > 1 {
		rollstring := strings.Join(os.Args[1:], " ")
		roll, err := dice.Parse(rollstring)
		if err != nil {
			fmt.Println(err)
			return
		}
		fmt.Printf("%+v\n", roll)
		fmt.Printf("%+v\n", roll.Roll())
	}
}
