package dice

import (
	"fmt"
	"math/rand"
	"slices"
	"strings"
)

type AdvantageState int

const (
	Normal AdvantageState = iota
	Advantage
	Disadvantage
)

type DieType int

const (
	D4   DieType = 4
	D6           = 6
	D8           = 8
	D10          = 10
	D12          = 12
	D20          = 20
	D100         = 100
)

func (d DieType) String() string {
	return fmt.Sprintf("D%d", d)
}

type RollComponent struct {
	Die   DieType
	Count int
}

type RollConfig struct {
	Components []RollComponent
	Modifier   int
	Advantage  AdvantageState
}

type DieResult struct {
	Die    DieType
	Result int
}

type RollResult struct {
	Total int
	Rolls []DieResult
	Other *RollResult
}

func (r RollResult) String() string {
	b := strings.Builder{}
	b.WriteString(fmt.Sprintf("%d", r.Total))

	outs := make(map[DieType][]int)
	for _, roll := range r.Rolls {
		outs[roll.Die] = append(outs[roll.Die], roll.Result)
	}
	keys := make([]DieType, 0, len(outs))
	for k := range outs {
		keys = append(keys, k)
	}
	slices.Sort(keys)
	for _, k := range keys {
		b.WriteString(fmt.Sprintf(" [%s:", k))
		for _, v := range outs[k] {
			b.WriteString(fmt.Sprintf(" %d", v))
		}
		b.WriteString(fmt.Sprintf("]"))
	}

	if r.Other != nil {
		b.WriteString(" (vs ")
		b.WriteString(r.Other.String())
		b.WriteString(")")
	}

	return b.String()
}

func (rc RollConfig) String() string {
	b := strings.Builder{}
	started := false
	for _, c := range rc.Components {
		if started {
			b.WriteString(" + ")
		}
		started = true
		b.WriteString(fmt.Sprintf("%dD%d", c.Count, c.Die))
	}
	if rc.Modifier != 0 {
		b.WriteString(fmt.Sprintf(" + %d", rc.Modifier))
	}
	switch rc.Advantage {
	case Advantage:
		b.WriteString(" (adv)")
	case Disadvantage:
		b.WriteString(" (dis)")
	}
	return b.String()
}

func (die DieType) Roll() int {
	val := rand.Intn(int(die)) + 1
	return val
}

func (rc *RollConfig) Roll() RollResult {
	rollOnce := func() RollResult {
		var results RollResult
		for _, c := range rc.Components {
			for range c.Count {
				val := c.Die.Roll()
				results.Rolls = append(results.Rolls, DieResult{
					Die:    c.Die,
					Result: val,
				})
				results.Total += val
			}
		}
		results.Total += rc.Modifier
		return results
	}
	switch rc.Advantage {
	case Normal:
		return rollOnce()
	default:
		r1 := rollOnce()
		r2 := rollOnce()
		if (rc.Advantage == Advantage && r1.Total > r2.Total) || (rc.Advantage == Disadvantage && r1.Total < r2.Total) {
			r1.Other = &r2
			return r1
		}
		r2.Other = &r1
		return r2
	}
}
